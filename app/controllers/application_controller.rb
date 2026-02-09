class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :set_nav_counts, if: :user_signed_in?

  def set_nav_counts
    @pending_suggestions_count = current_user.classification_suggestions.pending.count
  end
end
