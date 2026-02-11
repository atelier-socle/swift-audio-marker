import Foundation

/// An ordered, validated collection of chapters.
public struct ChapterList: Sendable, Hashable {

    private var chapters: [Chapter]

    /// Creates a chapter list from an array of chapters.
    /// - Parameter chapters: The initial chapters.
    public init(_ chapters: [Chapter] = []) {
        self.chapters = chapters
    }

    // MARK: - Mutation

    /// Appends a chapter to the end of the list.
    /// - Parameter chapter: The chapter to append.
    public mutating func append(_ chapter: Chapter) {
        chapters.append(chapter)
    }

    /// Inserts a chapter at the specified position.
    /// - Parameters:
    ///   - chapter: The chapter to insert.
    ///   - index: The position at which to insert.
    public mutating func insert(_ chapter: Chapter, at index: Int) {
        chapters.insert(chapter, at: index)
    }

    /// Removes and returns the chapter at the specified position.
    /// - Parameter index: The position of the chapter to remove.
    /// - Returns: The removed chapter.
    @discardableResult
    public mutating func remove(at index: Int) -> Chapter {
        chapters.remove(at: index)
    }

    // MARK: - Convenience

    /// Sorts chapters by start time in ascending order.
    public mutating func sort() {
        chapters.sort { $0.start < $1.start }
    }

    /// Clears all chapter end times so the writer recalculates them.
    ///
    /// Call this after modifying the chapter list (add, remove, re-order)
    /// to avoid stale end times that would cause overlap validation failures.
    public mutating func clearEndTimes() {
        for index in chapters.indices {
            chapters[index].end = nil
        }
    }

    /// Returns a new list with calculated end times based on next chapter starts and total duration.
    ///
    /// Each chapter's end time is set to the next chapter's start time.
    /// The last chapter's end time is set to the audio duration.
    ///
    /// - Parameter audioDuration: The total audio duration.
    /// - Returns: A new ``ChapterList`` with end times filled in.
    public func withCalculatedEndTimes(audioDuration: AudioTimestamp) -> ChapterList {
        var sorted = chapters.sorted { $0.start < $1.start }
        for index in sorted.indices {
            if index + 1 < sorted.count {
                sorted[index].end = sorted[index + 1].start
            } else {
                sorted[index].end = audioDuration
            }
        }
        return ChapterList(sorted)
    }
}

// MARK: - RandomAccessCollection

extension ChapterList: RandomAccessCollection {

    public var startIndex: Int { chapters.startIndex }
    public var endIndex: Int { chapters.endIndex }

    public subscript(position: Int) -> Chapter {
        chapters[position]
    }
}
