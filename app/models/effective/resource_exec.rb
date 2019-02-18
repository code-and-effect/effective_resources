# Makes sure resource in any instance_execs is the correct resource
module Effective
  class ResourceExec

    def initialize(instance, resource)
      @instance = instance
      @resource = resource
    end

    def resource
      @resource
    end

    def method_missing(method, *args, &block)
      @instance.send(method, *args)
    end

  end
end
