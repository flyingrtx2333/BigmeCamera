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

    /// 统计满足条件的元素数量（只遍历已写入的槽）
    func count(where predicate: (T) -> Bool) -> Int {
        storage.reduce(0) { acc, item in
            guard let item else { return acc }
            return acc + (predicate(item) ? 1 : 0)
        }
    }

    /// 遍历所有已写入的元素（按写入顺序，最旧→最新）
    func forEach(_ body: (T) -> Void) {
        guard count > 0 else { return }
        // 如果未满，从 0 开始；已满则从 writeIndex（最旧）开始
        let start = count < capacity ? 0 : writeIndex
        for i in 0..<count {
            if let item = storage[(start + i) % capacity] {
                body(item)
            }
        }
    }
}
