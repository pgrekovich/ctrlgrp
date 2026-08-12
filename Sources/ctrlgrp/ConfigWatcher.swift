import Foundation

/// Watches the config file's *directory* rather than the file itself. Editors
/// save by writing a temporary file and renaming it over the original, which
/// invalidates a file descriptor opened on the old inode; a descriptor on the
/// directory survives that and also catches the file being created for the
/// first time.
@MainActor
final class ConfigWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var pending: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        descriptor = open(directory.path(), O_EVTONLY)
        guard descriptor >= 0 else {
            Log.warn("cannot watch \(directory.path()), config reload is off")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleReload() }
        }
        source.setCancelHandler { [descriptor] in
            close(descriptor)
        }
        source.resume()
        self.source = source
    }

    func stop() {
        pending?.cancel()
        source?.cancel()
        source = nil
        descriptor = -1
    }

    /// A single save can produce several directory events. Coalesce them so
    /// the config is parsed once per edit.
    private func scheduleReload() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.onChange() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}
