module Effective
  class Resource
    include Effective::Resources::Init
    include Effective::Resources::Klass
    include Effective::Resources::Naming
    include Effective::Resources::Rest

    # post, Post, Admin::Post, admin::Post, admin/posts, admin/post, admin/effective::post
    def initialize(input)
      _initialize(input)
    end

  end
end
