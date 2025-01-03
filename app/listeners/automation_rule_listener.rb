class AutomationRuleListener < BaseListener
  def conversation_updated(event)
    conversation_event(event, 'conversation_updated')
  end

  def conversation_created(event)
    conversation_event(event, 'conversation_created')
  end

  def conversation_opened(event)
    conversation_event(event, 'conversation_opened')
  end

  def conversation_resolved(event)
    conversation_event(event, 'conversation_resolved')
  end

  def message_created(event)
    message = event.data[:message]

    return if ignore_message_created_event?(event)

    account = message.try(:account)
    changed_attributes = event.data[:changed_attributes]

    return unless rule_present?('message_created', account)

    rules = current_account_rules('message_created', account)

    rules.each do |rule|
      conditions_match = ::AutomationRules::ConditionsFilterService.new(rule, message.conversation,
                                                                        { message: message, changed_attributes: changed_attributes }).perform
      ::AutomationRules::ActionService.new(rule, account, message.conversation).perform if conditions_match.present?
    end
  end

  def rule_present?(event_name, account)
    return if account.blank?

    current_account_rules(event_name, account).any?
  end

  def current_account_rules(event_name, account)
    AutomationRule.where(
      event_name: event_name,
      account_id: account.id,
      active: true
    )
  end

  def performed_by_automation?(event)
    event.data[:performed_by].present? && event.data[:performed_by].instance_of?(AutomationRule)
  end

  def ignore_message_created_event?(event)
    message = event.data[:message]
    performed_by_automation?(event) || message.activity?
  end

  private

  def conversation_event(event, conversation_status)
    return if performed_by_automation?(event)

    conversation = event.data[:conversation]
    account = conversation.account
    changed_attributes = event.data[:changed_attributes]

    return unless rule_present?(conversation_status, account)

    rules = current_account_rules(conversation_status, account)

    rules.each do |rule|
      conditions_match = ::AutomationRules::ConditionsFilterService.new(rule, conversation, { changed_attributes: changed_attributes }).perform
      AutomationRules::ActionService.new(rule, account, conversation).perform if conditions_match.present?
    end
  end
end
