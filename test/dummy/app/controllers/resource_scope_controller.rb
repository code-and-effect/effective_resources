class ResourceScopeController < ApplicationController
  include Effective::CrudController

  resource_scope -> { Thing.all }
end
