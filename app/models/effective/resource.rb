module Effective
  class Resource
    include Effective::Resources::Init
    include Effective::Resources::Naming

    # post, Post, Admin::Post, admin::Post, admin/posts, admin/post, admin/effective::post
    def initialize(input)
      _initialize(input)
    end

  end
end
