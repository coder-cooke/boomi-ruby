class Boomi
  BASE_URI         = "https://platform.boomi.com/api/rest/v1"
  BASE_PARTNER_URI = "https://platform.boomi.com/partner/api/rest/v1"
  
  def initialize(opts)
    @resource         = RestClient::Resource.new(opts[:override_account] ? BASE_PARTNER_URI : BASE_URI, :user => opts[:user], :password => opts[:pass])
    @override_account = opts[:override_account]
    @account          = opts[:account]
  end

  def get_widget_list(widget_manager_id,partner_user_id)
    response(@resource["getWidgetList/#{widget_manager_id}/#{partner_user_id}?overrideAccountId=#{@override_account}"])
  end
  
  def get_account
    get(@resource["#{@account}/Account/query"])
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
    post("#{@account}/Account/query",query)
  end
  
  def get_events(opts)
    put("#{@account}/Event/query?overrideAccount=#{@override_account}", make_query(opts))
  end


  def get_execution_records(opts)
    post("#{@account}/ExecutionRecord/query?overrideAccount=#{@override_account}", make_query(opts))
  end
  
  def execute_process(atom_id,process_id)
    query = <<-EOS
<ProcessExecutionRequest processId="#{process_id}" atomId="#{atom_id}" xmlns="http://api.platform.boomi.com/">
    <ProcessProperties>
        <!-- Zero or more repetitions: -->
        <!-- TODO: parameterize this -->
        <!-- <ProcessProperty>
            <Name>?</Name>
            <Value>?</Value>
        </ProcessProperty> -->
    </ProcessProperties>
</ProcessExecutionRequest>
EOS
    post("#{@account}/executeProcess",query)
  end

  private
    def make_query(opts)
      query = <<-EXPR
<QueryConfig xmlns="http://api.platform.boomi.com/">
  <QueryFilter>
    <expression operator="and" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="GroupingExpression">
      #{opts.collect do |key,value| 
          field, operator = key.gsub(/\]/,'').split('[').collect(&:to_s)
          operator ||= 'EQUALS'

          "<nestedExpression operator='#{operator}' property='#{field}' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:type='SimpleExpression'>
              <argument>#{value.is_a?(Time) ? value.iso8601 : value}</argument>
          </nestedExpression>"
        end.join('\n')
      }
    </expression>
  </QueryFilter>
</QueryConfig>
EXPR
    end

    def get(url)
      contents = @resource[url].get
      parsed = parse(contents)
      parsed['queryToken'] 
    end

    def post(url,content)
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
          response = @resource[url].post(content)
        end
        if xml_doc = parse(response)       
          results += xml_doc['result'] if xml_doc['result']
          query_token = xml_doc['queryToken'] && xml_doc['queryToken'].first
        end
      rescue RestClient::BadRequest => e
        puts e.http_body
        error = true
      rescue RestClient::InternalServerError => e
        puts "Received error from server, stopped processing but dealing with any results that exist: #{e}"
        error = true
      end while query_token && !error && attempts < 50 
      results
    end
  
    def parse(content)
      return if content.blank?
      XmlSimple.xml_in(content)
    end
end
