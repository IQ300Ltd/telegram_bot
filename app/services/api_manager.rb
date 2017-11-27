class ApiManager 
 
  BASE_URL = 'https://app.iq300.ru'

  attr_reader :data, :error, :code
  

  def initialize(access_token)
    @access_token = access_token    
  end

  def login(email, pass)   
  begin 
    response = RestClient.post "#{BASE_URL}/api/v2/sessions/", {email: email, password: pass}
  rescue RestClient::ExceptionWithResponse => e
    response = e.response
  end
    parse_response(response)
  end

  def logout
    begin
      response = RestClient::Request.execute(method: :delete,
                                          url: "#{BASE_URL}/api/v2/sessions/",
                                          headers: {params: {access_token: @access_token}})
    rescue RestClient::ExceptionWithResponse => e
      response = e.response
    end
    parse_response(response)
  end

  def fetch_notification_counter  
    begin
      response = RestClient::Request.execute(method: :get,
                                          url: "#{BASE_URL}/api/v2/notifications/counters/",
                                          headers: {params: {access_token: @access_token}})
    rescue RestClient::ExceptionWithResponse => e
      response = e.response
    end
    parse_response(response)
  end

  def fetch_unread
    begin
      response = RestClient::Request.execute(method: :get,
                                          url: "#{BASE_URL}/api/v2/notifications/",
                                          headers: {params: {access_token: @access_token, unread: "true"}})
    rescue RestClient::ExceptionWithResponse => e
      response = e.response
    end
    parse_response(response)  
  end

  def wrong_token?
    @code == 401
  end

  private 

  def parse_response(response)
    @code = response.code.to_i
    @data = JSON.parse(response.body)
    if @code != 200
      @error = @data['error']
    end
  end

end