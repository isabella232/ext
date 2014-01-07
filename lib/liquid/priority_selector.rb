# encoding: utf-8

class PrioritySelector

  def add(element, priority)
    if @priority.nil? || priority > @priority
      @element = element
      @priority = priority
    end
  end

  def pick
    @element
  end

end
