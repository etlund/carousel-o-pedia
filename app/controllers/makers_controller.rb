class MakersController < ApplicationController
  def show
    @maker = Maker.find_by!(slug: params[:id])
  end
end
