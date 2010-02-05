class Array
  def rotate
    self.push(r = self.shift)
    return r
  end
end