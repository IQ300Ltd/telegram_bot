class TelegramController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  use_session!
  context_to_action!
  around_action :require_login, except: [:login, :start, :ru, :en]
  before_action :set_locale, except: [:ru, :en]

  def start(*)
    respond_with :message, text: t('.greeting')        
  end

  def login(*args)
    if args[0] == nil
      session['login_email'] = nil
      respond_with :message, text: t('.prompt_email')
      save_context :login
    elsif args[0] != nil && args[1] == nil  
      if session['login_email'] == nil
        session['login_email'] = args[0]
        respond_with :message, text: t('.prompt_password')
        save_context :login
      else
        login(session['login_email'], args[0])  
      end                                     
      
    else
      manager = ApiManager.new(nil)
      manager.login(args[0], args[1])
      if manager.error.present? 
        if manager.code == 422
          respond_with :message, text: t('.error.wrong_password')
        else
          respond_with :message, text: manager.error  
        end 
        session['login_email'] = nil     
      else 
        session[:access_token] = manager.data['access_token']
        respond_with :message, text: t('.login_success')
        manager = ApiManager.new(session[:access_token]) 
        manager.fetch_notification_counter  
        session[:notification_counter] = manager.data['notification_counters']['pinned'] +
                                     manager.data['notification_counters']['not_pinned_unread']
        respond_with :message,
                      text: "#{t('.unread_notifications')} #{session[:notification_counter]}",
                      reply_markup: { 
                        keyboard: [[t('.keyboard.new')], [t('.keyboard.list')]],
                        resize_keyboard: true
                      }    
      end
    end 
  end

  def logout(*)
    manager = ApiManager.new(session['access_token'])
    manager.logout
    if manager.error.present?       
      respond_with :message, text: manager.error  
      if manager.wrong_token?
        session['access_token'] = nil
        respond_with :message, text: t('.error.wrong_token')
      end    
    else
      session['access_token'] = nil
      respond_with :message, text: t('.logout_success'), reply_markup: {remove_keyboard: true}
    end
  end

  def new(*)    
    manager = ApiManager.new(session['access_token'])
    manager.fetch_notification_counter 
    if manager.error.present? 
      respond_with :message, text: manager.error  
      if manager.wrong_token?
        session['access_token'] = nil
        respond_with :message, text: t('.error.wrong_token')
      end    
    else
      session[:notification_counter] = manager.data['notification_counters']['pinned'] +
                                     manager.data['notification_counters']['not_pinned_unread']    
      if session[:notification_counter] > 0
        respond_with :message,
                      text: "#{t('.unread_notifications')} #{session[:notification_counter]}"
      else
        respond_with :message, text: t('.no_new_notifications')
      end
    end
  end

  def list(*)
    manager = ApiManager.new(session['access_token'])
    manager.fetch_unread
    if manager.error.present? 
      respond_with :message, text: manager.error  
      if manager.wrong_token?
        session['access_token'] = nil
        respond_with :message, text: t('.error.wrong_token')
      end    
    else 
      if manager.data['notifications'].length == 0
        respond_with :message, text: t('.no_unread_notifications')
      else
        text = manager.data['notifications'].map do |n|
          "• #{n['user']['short_name']} #{n['main_text']}"
        end.join("\n")
        text << "\n https://app.iq300.ru/notifications?folder=new"
        respond_with :message, text: text
      end
    end
  end

  def en(*)
    I18n.locale = :en
    session['locale'] = :en
    unless session['access_token'].present? 
      start
    else
      respond_with :message,
              text: "English enabled",
              reply_markup: { 
                keyboard: [[t('.keyboard.new')], [t('.keyboard.list')]],
                resize_keyboard: true
              }  
    end
  end

  def ru(*)
    I18n.locale = :ru
    session['locale'] = :ru
    unless session['access_token'].present? 
      start
    else
      respond_with :message,
              text: "Русский язык включен",
              reply_markup: { 
                keyboard: [[t('.keyboard.new')], [t('.keyboard.list')]],
                resize_keyboard: true
              }  
    end
  end


  def message(message, *args)
    if message['text'] == t('.keyboard.new')
      new(args)
    elsif message['text'] == t('.keyboard.list')
      list(args)
    else
      respond_with :message, text: t('.error.wrong_command')   
    end
  end

  def action_missing(action, *_args)
      respond_with :message, text: t('.error.wrong_command')    
  end

  private

    def require_login(&block)      
      if session['access_token'].present?
        yield        
      else
        respond_with :message, text: t('.error.no_auth')         
      end
    end   

    def set_locale
      if session[:locale].present?
        I18n.locale = session[:locale]
      end
    end
end