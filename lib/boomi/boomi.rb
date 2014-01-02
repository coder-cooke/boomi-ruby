class Boomi
  BASE_URI         = "https://platform.boomi.com/api/rest/v1"
  BASE_PARTNER_URI = "https://platform.boomi.com/partner/api/rest/v1"

  def initialize(opts)
    opts = symbolize_keys(opts)
    @resource         = RestClient::Resource.new(opts[:override_account] ? BASE_PARTNER_URI : BASE_URI, :user => opts[:user], :password => opts[:pass], :timeout => opts[:timeout] || 60)
    @override_account = opts[:override_account]
    @account          = opts[:account]
  end

  def get_widget_list(widget_manager_id, partner_user_id)
    response(@resource["getWidgetList/#{widget_manager_id}/#{partner_user_id}?overrideAccountId=#{@override_account}"])
  end
  
  def get_account
    get(make_url("Account/query", :override => false))
  end
  
  def query_account
    query = <<-EOS
              <QueryConfig xmlns="http://api.platform.boomi.com/">
                <QueryMore>
                    <QueryToken>%s</QueryToken>
                </QueryMore>
                <QueryFilter>
                  <expression operator="and" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                    xsi:type="GroupingExpression">
              <nestedExpression operator="GREATER_THAN_OR_EQUAL" property="dateCreated"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="SimpleExpression">
                      <argument>1980-01-01T00:00:00Z</argument>
                    </nestedExpression>
                  </expression>
                </QueryFilter>
              </QueryConfig>
            EOS

    post("#{@account}/Account/query", query)
  end
  
  def get_events(opts)
    post(make_url("Event/query"), make_query(opts))
  end

  def get_execution_records(opts)
    post(make_url("ExecutionRecord/query"), make_query(opts))
  end

  def get_environment_extensions_xml(environment_id)
    get(make_url("EnvironmentExtensions/#{environment_id}"), :parse_response => false)
  end

  def set_environment_extensions_xml(environment_id, request_xml)
    post(make_url("EnvironmentExtensions/#{environment_id}"), request_xml, :paginated_response => false, :parse_response => false)
  end

  def copy_environment_extensions_xml(from_id, to_id)
    request = get_environment_extensions_xml(from_id).sub!(/#{from_id}/, to_id)
    set_environment_extensions_xml(to_id, request)
  end

  def execute_process(atom_id, process_id, process_hash)
    request_head = "<ProcessExecutionRequest processId=\"#{process_id}\" atomId=\"#{atom_id}\" xmlns=\"http://api.platform.boomi.com/\">"
    request_tail = "</ProcessExecutionRequest>"

    if process_hash.nil? or process_hash.empty?
      query = request_head + request_tail
    elsif !process_hash.nil? and !process_hash.empty? and process_hash.is_a? Hash
      request_head += "<ProcessProperties>\n"

      process_hash.each do |key, value|
        request_head += <<-EOS
                          <ProcessProperty>
                            <Name>#{key}</Name>
                            <Value>#{value}</Value>
                          </ProcessProperty>
                        EOS
      end

      query = request_head + "</ProcessProperties>\n" + request_tail
    end

    post("#{@account}/executeProcess", query)
  end

  private

    def build_process_prop_str(properties_hash)

    end

    def symbolize_keys(hash)
      Hash[hash.map{ |k, v| [k.to_sym, v] }]
    end

    def make_url(url, opts={})
      opts = { :override => true }.merge(opts)
      "#{@account}/#{url}"+(opts[:override] && @override_account ? "?overrideAccount=#{@override_account}" : "")
    end

    def make_query(opts)
      query = <<-EXPR
                <QueryConfig xmlns="http://api.platform.boomi.com/">
                  <QueryFilter>
                    <expression operator="and" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="GroupingExpression">
                      #{opts.collect do |key,value| 
                          field, operator = key.gsub(/\]/,'').split('[').collect(&:to_s)
                          operator ||= 'EQUALS'

                          "<nestedExpression operator='#{operator}' property='#{field}' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:type='SimpleExpression'>
                              <argument>#{value.is_a?(Time) ? boomi_time(value) : value}</argument>
                          </nestedExpression>"
                        end.join("\n")
                      }
                    </expression>
                  </QueryFilter>
                </QueryConfig>
              EXPR
    end

    def boomi_time(t)
      t.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    end

    def get(url,opts={})
      opts = { :parse_response => true }.merge(opts)
      opts[:parse_response] ? parse(@resource[url].get) : @resource[url].get
    end

    def post(url,content,opts={})
      opts = { :parse_response => true, :paginated_response => true }.merge(opts)
      results = []
      response = ''
      query_token = nil
      error = false
      attempts = 0
      begin
        attempts += 1
        if query_token
          response = @resource["#{url.gsub(/query/,'queryMore')}"].post(query_token)
        else
          response = @resource[url].post(content);
        end
        if opts[:paginated_response] && xml_doc = parse(response)
          results =
            if xml_doc['result']
              xml_doc['result'].is_a?(Array) ? results + xml_doc['result'] : [xml_doc['result']]
            end
          query_token = xml_doc['queryToken']
        else
          return opts[:parse_response] ? parse(response) : response
        end
      end while query_token && !error && attempts < 50
      results
    end
  
    def parse(content)
      return if content.to_s.empty?
      xml_simple.xml_in(content.to_s)
    end

    # For some reason XmlSimple breaks in some dependencies when use with the class method syntax
    def xml_simple
      @simple ||= XmlSimple.new('NoAttr' => true, 'ForceArray' => false)
    end
end