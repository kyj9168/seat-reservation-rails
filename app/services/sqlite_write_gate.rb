class SqliteWriteGate
  MUTEX = Mutex.new

  def self.synchronize(&block)
    MUTEX.synchronize(&block)
  end
end
