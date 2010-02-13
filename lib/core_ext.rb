class Array
  def rotate
    ## Solution #1 by greg
    # self.push(r = self.shift)
    # return r
    
    ## Solution #2 by madx
    # shift.tap {|e| push e }
    
    ## Solution #3 by greg
    push(shift)[-1]
  end
end
