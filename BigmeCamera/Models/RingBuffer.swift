/// 固定容量循环缓冲区，写满后自动覆盖最旧元素，无需动态扩容或 removeAll
struct RingBuffer<T> {
    private var storage: [T?]
    private var writeIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.storage = [T?](repeating: nil, count: capacity)
    }

    mutating func append(_ element: T) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity { count += 1 }
    }

    func count(where predicate: (T) -> Bool) -> Int {
        storage.reduce(0) { acc, item in
            guard let item else { return acc }
            return acc + (predicate(item) ? 1 : 0)
        }
    }
}
