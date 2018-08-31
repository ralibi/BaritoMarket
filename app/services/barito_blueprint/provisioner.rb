module BaritoBlueprint
  class Provisioner
    DEFAULTS = {
      timeout: 5.minutes,
      check_interval: 5.seconds
    }

    def initialize(infrastructure, executor, opts = {})
      @infrastructure = infrastructure
      @infrastructure_components = @infrastructure.infrastructure_components
      @executor = executor
      @defaults = {
        timeout: opts[:timeout] || DEFAULTS[:timeout],
        check_interval: opts[:check_interval] || DEFAULTS[:check_interval],
      }
    end

    def provision_instances!
      Processor.produce_log(@infrastructure, 'Provisioning started')
      @infrastructure.update_provisioning_status('PROVISIONING_STARTED')

      @infrastructure_components.each do |component|
        success = provision_instance!(component)
        unless success
          Processor.produce_log(@infrastructure, 'Provisioning error')
          @infrastructure.update_provisioning_status('PROVISIONING_ERROR')
          return false
        end
      end

      Processor.produce_log(@infrastructure, 'Provisioning finished')
      @infrastructure.update_provisioning_status('PROVISIONING_FINISHED')
      return true
    end

    def provision_instance!(component)
      Processor.produce_log(
        @infrastructure,
        "InfrastructureComponent:#{component.id}",
        "Provisioning #{component.hostname} started")
      component.update_status('PROVISIONING_STARTED')

      # Execute provisioning
      res = @executor.provision!(component.hostname)
      Processor.produce_log(
        @infrastructure,
        "InfrastructureComponent:#{component.id}",
        "#{res}")

      if res['success'] == true
        Processor.produce_log(
          @infrastructure,
          "InfrastructureComponent:#{component.id}",
          "Provisioning #{component.hostname} finished")
        component.update_status('PROVISIONING_FINISHED')
        return true
      else
        Processor.produce_log(
          @infrastructure,
          "InfrastructureComponent:#{component.id}",
          "Provisioning #{component.hostname} error",
          "#{res['error']}")
        component.update_status('PROVISIONING_ERROR', res['error'].to_s)
        return false
      end
    end

    def reprovision_instance!(component)
      Processor.produce_log(
        @infrastructure,
        "InfrastructureComponent:#{component.id}",
        "Provisioning #{component.hostname} started")
      component.update_status('PROVISIONING_STARTED')

      # Execute reprovisioning
      res = @executor.reprovision!(component.hostname)
      Processor.produce_log(
        @infrastructure,
        "InfrastructureComponent:#{component.id}",
        "#{res}")

      if res['success'] == true
        Processor.produce_log(
          @infrastructure,
          "InfrastructureComponent:#{component.id}",
          "Provisioning #{component.hostname} finished")
        component.update_status('PROVISIONING_FINISHED')
        return true
      else
        Processor.produce_log(
          @infrastructure,
          "InfrastructureComponent:#{component.id}",
          "Provisioning #{component.hostname} error",
          "#{res['error']}")
        component.update_status('PROVISIONING_ERROR', res['error'].to_s)
        return false
      end
    end

    def check_and_update_instances
      @infrastructure.update_provisioning_status('PROVISIONING_CHECK_STARTED')

      success = false
      end_time = DateTime.current + @defaults[:timeout]
      while !success && DateTime.current <= end_time
        @infrastructure_components.each do |component|
          unless valid_instance?(component)
            component.update_status('PROVISIONING_CHECK_STARTED')
            check_and_update_instance(component)
          end
        end

        success = valid_instances?(@infrastructure_components)
        break if success

        sleep(@defaults[:check_interval])
      end

      @infrastructure_components.each do |component|
        check_and_update_instance(component, update_status: true)
      end
      success = valid_instances?(@infrastructure_components)

      if success
        @infrastructure.
          update_provisioning_status('PROVISIONING_CHECK_SUCCEED')
        return true
      else
        @infrastructure.update_provisioning_status('PROVISIONING_CHECK_FAILED')
        return false
      end
    end

    def check_and_update_instance(component, update_status: false)
      component.update(ipaddress: nil)
      res = @executor.show_container(component.hostname)
      ipaddress = res.dig('data', 'ipaddress')
      if ipaddress
        component.update(ipaddress: ipaddress)
        component.update_status('PROVISIONING_CHECK_SUCCEED') if update_status
        return true
      else
        component.update_status('PROVISIONING_CHECK_FAILED', res['error'].to_s) if update_status
        return false
      end
    end

    def valid_instances?(components)
      components.all?{ |component| valid_instance?(component)}
    end

    def valid_instance?(component)
      return false unless component.ipaddress
      return true
    end
  end
end