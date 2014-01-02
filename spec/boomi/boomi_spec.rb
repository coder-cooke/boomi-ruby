require 'spec_helper'
require 'time'

describe Boomi do
  XML_PATH = File.join(File.dirname(__FILE__), "..", "xml")

  before do
    # log to stdout & proxy
    # RestClient.log = Logger.new(STDOUT)
    # RestClient.proxy = 'http://localhost:8080/'

    # FakeWeb.allow_net_connect = false
  end

  context "parent account" do
    before do
      @boomi = Boomi.new(:account => 'boo-me', :user => 'boo-user', :pass => 'boo-you')
    end

    describe 'Boomi access' do
      it 'should be able to retrieve accounts' do
        FakeWeb.register_uri(:get, %r(https://.*@platform.boomi.com/api/rest/v1/.*/Account/.*), :body => File.join(XML_PATH, "Account-GET.xml"))
        @boomi.get_account['user'].size.should == 2
      end

      it 'should be able to retrieve execution records' do
        FakeWeb.register_uri(:post, %r(https://.*@platform.boomi.com/api/rest/v1/.*/ExecutionRecord/.*), :body => File.join(XML_PATH, "getExecutionRecord-3results.xml"))
        records = @boomi.get_execution_records("executionTime[GREATER_THAN_OR_EQUAL]" => Time.now-15*60)
        records.size.should == 3
        records.first['account'].should == 'Boupa'
      end

      it 'should be able to retrieve events for execution record' do
        FakeWeb.register_uri(:post, %r(https://.*@platform.boomi.com/api/rest/v1/.*/ExecutionRecord/.*), :body => File.join(XML_PATH, "getExecutionRecord-3results.xml"))
        FakeWeb.register_uri(:post, %r(https://.*@platform.boomi.com/api/rest/v1/.*/Event/.*), :body => File.join(XML_PATH, "getEvent-1result.xml"))
        records = @boomi.get_execution_records("executionTime[GREATER_THAN_OR_EQUAL]" => Time.now-15*60)
        records.size.should == 3
        events = @boomi.get_events("executionId[EQUALS]" => records[0]['executionId'], "eventDate[GREATER_THAN_OR_EQUAL]" => records[0]['executionTime'])
        events.size.should == 1
      end

      it 'should be able to copy environment extensions' do
        FakeWeb.register_uri(:get, %r(https://.*@platform.boomi.com/api/rest/v1/.*/EnvironmentExtensions/myfakeaccount), :body => File.join(XML_PATH, "getEnvironmentExtensions.xml"))
        FakeWeb.register_uri(:post, %r(https://.*@platform.boomi.com/api/rest/v1/.*/EnvironmentExtensions/mynewaccount), :body => File.join(XML_PATH, "getEnvironmentExtensions.xml"))
        records = @boomi.copy_environment_extensions_xml("myfakeaccount", "mynewaccount")
        records.should_not be_empty
      end

      it 'should be able to use dynamic process properties' do
        # Execute a process and provide a hash of dynamic process property names and values
        FakeWeb.register_uri(:post, %r(https://.*@platform.boomi.com/api/rest/v1/.*/executeProcess), :body => File.join(XML_PATH, "getExecutionRecord-3results.xml"))
        extensions = {"StartTime" => "2013-09-20T00:00:00.000Z", "EndTime" => "2013-09-30T00:00:00.000Z"}
        @boomi.execute_process("test_atom_id", "test_process_id", extensions)
        records = @boomi.get_execution_records("executionTime[GREATER_THAN_OR_EQUAL]" => Time.now-15*60)
        records.size.should == 3
        records.first['account'].should == 'Boupa'

        events = @boomi.get_events("executionId[EQUALS]" => records[0]['executionId'], "eventDate[GREATER_THAN_OR_EQUAL]" => records[0]['executionTime'])
        events.size.should == 1

        # Execute a process and provide nil, instead of a hash of dynamic process property names and values
        @boomi.execute_process("test_atom_id", "test_process_id", nil)
        records = @boomi.get_execution_records("executionTime[GREATER_THAN_OR_EQUAL]" => Time.now-15*60)
        records.size.should == 3
        records.first['account'].should == 'Boupa'

        events = @boomi.get_events("executionId[EQUALS]" => records[0]['executionId'], "eventDate[GREATER_THAN_OR_EQUAL]" => records[0]['executionTime'])
        events.size.should == 1

        # Execute a process and provide an empty hash, to ensure there is still no error
        empty_extensions = {}

        @boomi.execute_process("test_atom_id", "test_process_id", empty_extensions)
        records = @boomi.get_execution_records("executionTime[GREATER_THAN_OR_EQUAL]" => Time.now-15*60)
        records.size.should == 3
        records.first['account'].should == 'Boupa'

        events = @boomi.get_events("executionId[EQUALS]" => records[0]['executionId'], "eventDate[GREATER_THAN_OR_EQUAL]" => records[0]['executionTime'])
        events.size.should == 1
      end

    end
  end
end