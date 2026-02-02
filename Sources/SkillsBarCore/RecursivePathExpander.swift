import Foundation

/// Utility to expand parent directories to their immediate subdirectories
public struct RecursivePathExpander: Sendable {
    /// Expand parent paths to immediate subdirectories (skips hidden directories)
    /// - Parameter recursivePaths: Parent directories to scan
    /// - Returns: Array of immediate subdirectories that exist and are not hidden
    public static func expand(_ recursivePaths: [URL]) -> [URL] {
        var expandedPaths: [URL] = []
        let fileManager = FileManager.default

        for parentPath in recursivePaths {
            guard fileManager.fileExists(atPath: parentPath.path) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: parentPath,
                    includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                    options: [.skipsHiddenFiles]
                )

                for url in contents {
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                    if resourceValues.isDirectory == true {
                        expandedPaths.append(url)
                    }
                }
            } catch {
                // Skip paths that can't be read
                continue
            }
        }

        return expandedPaths
    }

    /// Count the number of immediate subdirectories in a parent path
    /// - Parameter parentPath: The parent directory to scan
    /// - Returns: Number of subdirectories (excluding hidden)
    public static func subfolderCount(for parentPath: URL) -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: parentPath.path) else { return 0 }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: parentPath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            return contents.filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }.count
        } catch {
            return 0
        }
    }

    /// Check if a folder is already covered by a recursive parent folder
    /// - Parameters:
    ///   - folder: The folder to check
    ///   - recursivePaths: List of folders with recursive scanning enabled
    /// - Returns: The parent folder that covers this one, or nil if not covered
    public static func coveredByRecursive(_ folder: URL, in recursivePaths: [URL]) -> URL? {
        let folderPath = folder.standardizedFileURL.path
        for recursivePath in recursivePaths {
            let parentPath = recursivePath.standardizedFileURL.path
            // Check if folder is an immediate subdirectory of a recursive path
            if folderPath.hasPrefix(parentPath + "/") {
                let remaining = String(folderPath.dropFirst(parentPath.count + 1))
                // Only immediate children (no additional slashes)
                if !remaining.contains("/") {
                    return recursivePath
                }
            }
        }
        return nil
    }
}
