module Effective
  class Resource
    include Effective::Resources::Associations
    include Effective::Resources::Attributes
    include Effective::Resources::Init
    include Effective::Resources::Klass
    include Effective::Resources::Naming
    include Effective::Resources::Paths

    # post, Post, Admin::Post, admin::Post, admin/posts, admin/post, admin/effective::post
    def initialize(input)
      _initialize(input)
    end

    def to_s
      name
    end

  end
end
