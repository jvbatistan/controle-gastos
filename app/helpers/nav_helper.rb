module NavHelper
  def nav_item_class(path)
    base = "list-group-item list-group-item-action d-flex align-items-center gap-2 py-3 rounded-3 mb-2 border-0"
    current_page?(path) ? "#{base} active shadow-sm" : "#{base} text-body"
  end
end
