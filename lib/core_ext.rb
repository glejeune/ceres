class Array
  def rotate
    shift.tap {|e| push e }
  end
end
