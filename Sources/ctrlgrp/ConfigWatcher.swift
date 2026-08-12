import Foundation

/// Watches the config file so hand edits take effect without a restart.
///
/// Two sources are needed because no single event covers every way a file
/// gets saved:
/// - A source on the config file's *directory* catches the file being
///   created for the first time, and catches "write a temp file, then rename
///   it over the original" saves (a common editor save strategy). The rename
///   swaps out the directory entry, which invalidates any descriptor already
///   opened on the old file and would otherwise leave a file-level watcher
///   silently pointed at a dead inode.
/// - A source on the file itself catches in-place rewrites (`cat >`,
///   `echo >`, `jq ... >`, or any tool that truncates and rewrites the
///   existing inode) that never touch the directory entry, so the directory
///   source alone would miss them entirely and silently.
///
/// Whenever the directory reports a change, the file source is closed and
/// reopened, because a rename-over swaps the underlying inode out from under
/// the old descriptor; reopening is what "re-arms" coverage for the next
/// in-place rewrite of whatever file now sits at that path.
@MainActor
final class ConfigWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryDescriptor: CInt = -1
    private var fileSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var pending: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        // A second start() while already active would leave the first
        // source's descriptor and handler alive forever, firing duplicate
        // reloads against a still-live self.
        guard directorySource == nil else { return }

        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // percentEncoded: false, or a home directory with a space or
        // non-ASCII character turns into a path open() cannot find.
        let directoryPath = directory.path(percentEncoded: false)
        directoryDescriptor = open(directoryPath, O_EVTONLY)
        guard directoryDescriptor >= 0 else {
            Log.warn("cannot watch \(directoryPath), config reload is off")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.scheduleReload()
                self?.rearmFileWatch()
            }
        }
        source.setCancelHandler { [directoryDescriptor] in
            close(directoryDescriptor)
        }
        source.resume()
        self.directorySource = source

        rearmFileWatch()
    }

    func stop() {
        pending?.cancel()
        directorySource?.cancel()
        directorySource = nil
        directoryDescriptor = -1
        fileSource?.cancel()
        fileSource = nil
        fileDescriptor = -1
    }

    /// Re-opens the file-level watch on whatever currently sits at `url`.
    /// Called on the initial start() and again after every directory event,
    /// since a rename-over means the old descriptor now points at an
    /// unlinked, orphaned inode rather than the file a reader would open.
    private func rearmFileWatch() {
        fileSource?.cancel()
        fileSource = nil
        fileDescriptor = -1

        let path = url.path(percentEncoded: false)
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else {
            // File does not exist right now (e.g. deleted, or not created
            // yet); the directory source will call back in here once it does.
            return
        }
        fileDescriptor = descriptor

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleReload() }
        }
        source.setCancelHandler { [descriptor] in
            close(descriptor)
        }
        source.resume()
        fileSource = source
    }

    /// A single save can produce several events, sometimes from both
    /// sources at once (a rename-over fires the directory source and
    /// invalidates the file source's old descriptor). Coalesce them so the
    /// config is parsed once per edit.
    private func scheduleReload() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.onChange() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}
