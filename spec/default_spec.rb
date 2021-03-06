require 'spec_helper'

describe 'rsyslog::default' do
  let(:chef_run) do
    ChefSpec::ChefRunner.new(platform: 'ubuntu', version: '12.04').converge('rsyslog::default')
  end

  let(:service_resource) { 'service[rsyslog]' }

  it 'installs the rsyslog part' do
    expect(chef_run).to install_package('rsyslog')
  end

  context "when node['rsyslog']['relp'] is true" do
    let(:chef_run) do
      ChefSpec::ChefRunner.new(platform: 'ubuntu', version: '12.04') do |node|
        node.set['rsyslog']['use_relp'] = true
      end.converge('rsyslog::default')
    end

    it 'installs the rsyslog-relp package' do
      expect(chef_run).to install_package('rsyslog-relp')
    end
  end

  context '/etc/rsyslog.d directory' do
    let(:directory) { chef_run.directory('/etc/rsyslog.d') }

    it 'creates the directory' do
      expect(chef_run).to create_directory(directory.path)
    end

    it 'is owned by root:root' do
      expect(directory.owner).to eq('root')
      expect(directory.group).to eq('root')
    end

    it 'has 0755 permissions' do
      expect(directory.mode).to eq('0755')
    end

    context 'on SmartOS' do
      let(:chef_run) do
        ChefSpec::ChefRunner.new(platform: 'smartos', version: 'joyent_20130111T180733Z').converge('rsyslog::default')
      end

      let(:directory) { chef_run.directory('/opt/local/etc/rsyslog.d') }

      it 'creates the directory' do
        expect(chef_run).to create_directory(directory.path)
      end

      it 'is owned by root:root' do
        expect(directory.owner).to eq('root')
        expect(directory.group).to eq('root')
      end

      it 'has 0755 permissions' do
        expect(directory.mode).to eq('0755')
      end
    end
  end

  context '/var/spool/rsyslog directory' do
    let(:directory) { chef_run.directory('/var/spool/rsyslog') }

    it 'creates the directory' do
      expect(chef_run).to create_directory('/var/spool/rsyslog')
    end

    it 'is owned by root:root' do
      expect(directory.owner).to eq('root')
      expect(directory.group).to eq('root')
    end

    it 'has 0755 permissions' do
      expect(directory.mode).to eq('0755')
    end
  end

  context '/etc/rsyslog.conf template' do
    let(:template) { chef_run.template('/etc/rsyslog.conf') }
    let(:modules) { %w(imuxsock imklog) }

    it 'creates the template' do
      expect(chef_run).to create_file_with_content(template.path, 'Configuration file for rsyslog v3')
    end

    it 'is owned by root:root' do
      expect(template.owner).to eq('root')
      expect(template.group).to eq('root')
    end

    it 'has 0644 permissions' do
      expect(template.mode).to eq('0644')
    end

    it 'notifies restarting the service' do
      expect(template).to notify(service_resource, :restart)
    end

    it 'includes the right modules' do
      modules.each do |mod|
        expect(chef_run).to create_file_with_content(template.path, /^\$ModLoad #{mod}/)
      end
    end

    context 'on SmartOS' do
      let(:chef_run) do
        ChefSpec::ChefRunner.new(platform: 'smartos', version: 'joyent_20130111T180733Z').converge('rsyslog::default')
      end

      let(:template) { chef_run.template('/opt/local/etc/rsyslog.conf') }
      let(:modules) { %w(immark imsolaris imtcp imudp) }

      it 'creates the template' do
        expect(chef_run).to create_file_with_content(template.path, 'Configuration file for rsyslog v3')
      end

      it 'is owned by root:root' do
        expect(template.owner).to eq('root')
        expect(template.group).to eq('root')
      end

      it 'has 0644 permissions' do
        expect(template.mode).to eq('0644')
      end

      it 'notifies restarting the service' do
        expect(template).to notify(service_resource, :restart)
      end

      it 'includes the right modules' do
        modules.each do |mod|
          expect(chef_run).to create_file_with_content(template.path, /^\$ModLoad #{mod}/)
        end
      end
    end
  end

  context '/etc/rsyslog.d/50-default.conf template' do
    let(:template) { chef_run.template('/etc/rsyslog.d/50-default.conf') }

    it 'creates the template' do
      expect(chef_run).to create_file_with_content('/etc/rsyslog.d/50-default.conf', '*.emerg    *')
    end

    it 'is owned by root:root' do
      expect(template.owner).to eq('root')
      expect(template.group).to eq('root')
    end

    it 'has 0644 permissions' do
      expect(template.mode).to eq('0644')
    end

    it 'notifies restarting the service' do
      expect(template).to notify(service_resource, :restart)
    end

    context 'on SmartOS' do
      let(:chef_run) do
        ChefSpec::ChefRunner.new(platform: 'smartos', version: 'joyent_20130111T180733Z').converge('rsyslog::default')
      end

      let(:template) { chef_run.template('/opt/local/etc/rsyslog.d/50-default.conf') }

      it 'creates the template' do
        expect(chef_run).to create_file_with_content(template.path, 'Default rules for rsyslog.')
      end

      it 'is owned by root:root' do
        expect(template.owner).to eq('root')
        expect(template.group).to eq('root')
      end

      it 'has 0644 permissions' do
        expect(template.mode).to eq('0644')
      end

      it 'notifies restarting the service' do
        expect(template).to notify(service_resource, :restart)
      end

      it 'uses the SmartOS-specific template' do
        expect(chef_run).to create_file_with_content(template.path, %r{/var/adm/messages$})
      end
    end
  end

  context 'COOK-3608 maillog regression test' do
    let(:chef_run) do
      ChefSpec::ChefRunner.new(platform: 'redhat', version: '6.3').converge('rsyslog::default')
    end

    it 'outputs mail.* to /var/log/maillog' do
      expect(chef_run).to create_file_with_content('/etc/rsyslog.d/50-default.conf', 'mail.*    -/var/log/maillog')
    end
  end

  context 'syslog service' do
    let(:chef_run) do
      ChefSpec::ChefRunner.new(platform: 'redhat', version: '5.8').converge('rsyslog::default')
    end

    it 'stops and starts the syslog service on RHEL' do
      expect(chef_run).to stop_service('syslog')
      expect(chef_run).to disable_service('syslog')
    end
  end

  context 'system-log service' do
    let(:chef_run) do
      ChefSpec::ChefRunner.new(platform: 'smartos', version: 'joyent_20130111T180733Z').converge('rsyslog::default')
    end

    it 'stops the system-log service on SmartOS' do
      expect(chef_run).to disable_service('system-log')
    end
  end

  context 'rsyslog service' do
    it 'starts and enables the service' do
      expect(chef_run).to set_service_to_start_on_boot('rsyslog')
    end
  end
end
