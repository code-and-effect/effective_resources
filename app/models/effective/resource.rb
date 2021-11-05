module Effective
  class Resource
    include Effective::Resources::Actions
    include Effective::Resources::Associations
    include Effective::Resources::Attributes
    include Effective::Resources::Controller
    include Effective::Resources::Init
    include Effective::Resources::Instance
    include Effective::Resources::Forms
    include Effective::Resources::Generator
    include Effective::Resources::Klass
    include Effective::Resources::Model
    include Effective::Resources::Naming
    include Effective::Resources::Paths
    include Effective::Resources::Relation
    include Effective::Resources::Sql
    include Effective::Resources::Tenants

    # In practice, this is initialized two ways
    # With a klass and a namespace from effective_datatables
    # Or with a controller_path from crud controller

    # post, Post, Admin::Post, admin::Post, admin/posts, admin/post, admin/effective::post
    def initialize(input, namespace: nil, relation: nil, &block)
      _initialize_input(input, namespace: namespace, relation: relation)

      # This is an effective_resource do ... end block
      _initialize_model(&block) if block_given?

      self
    end

    def to_s
      name
    end

  end
end
