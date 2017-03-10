class WebsitesController < ApplicationController
  def index
    @websites = current_user.websites
  end

  def show
    @website = Website.find(params[:id])
    @articles = @website.articles.order("crawled DESC").order("total_shares DESC")
    respond_to do |format|
      format.html
      format.xls do
        headers["Content-Disposition"] = "attachment; filename=\"#{@website.link}\""
        send_data @website.to_csv(col_sep: "\t")
      end
    end
  end

  def new

  end

  def destroy
    current_user.websites.delete(params[:id].to_i)
    redirect_to websites_path
  end
end
