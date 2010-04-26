module ProjectTasksHelper
  
  def operators_for_select(filter_type)
     Query.operators_by_filter_type[filter_type].collect {|o| [l(Query.operators[o]), o]}
   end

   def column_header(column)
     column.sortable ? sort_header_tag(column.name.to_s, :caption => column.caption,
                                                         :default_order => column.default_order) : 
                       content_tag('th', column.caption)
   end
   
   def column_new_header(column)
     content_tag('th', column.caption)
   end
  
  
  def column_content_form(form, column, issue)
    value = column.value(issue)
    
    case value.class.name
    when 'String'
        form.text_field column.name
    when 'Time'
      format_time(value)
    when 'Date'
      issue_id = "issue_#{issue.id}_#{column.name.to_s}"
      "#{form.text_field :due_date, :size => 10} #{calendar_for(issue_id)}"
    when 'Fixnum', 'Float'
      form.text_field column.name, :size => 5
    when 'User'
      form.select column.name, options_from_collection_for_select(@project.members, :id, :name, value.id), {:include_blank => true}
    when 'Project'      
      link_to(h(value), :controller => 'projects', :action => 'show', :id => value)
    when 'Version'
      form.select column.name, options_from_collection_for_select(@project.versions, :id, :name, value.id), {:include_blank => true}
    when 'TrueClass'
      l(:general_text_Yes)
    when 'FalseClass'
      l(:general_text_No)
    when 'Tracker'
      form.select column.name, options_from_collection_for_select(@project.trackers, :id, :name, value.id), {:include_blank => true}
    when 'Priority'
      
    when 'Status'
      
    when 'NilClass'
      
      if column.name.to_s == "assigned_to"
        form.select column.name, options_from_collection_for_select(@project.members, :id, :name), {:include_blank => true}
      elsif column.name.to_s == "fixed_version"
        form.select column.name, options_from_collection_for_select(@project.versions, :id, :name), {:include_blank => true}
      elsif column.name.to_s == "category"
        form.select column.name, options_from_collection_for_select(@project.issue_categories, :id, :name), {:include_blank => true}
      elsif column.name.to_s == "estimated_hours"
        form.text_field column.name, :size => 5
      elsif column.name.to_s == "due_date"
        issue_id = "issue_#{issue.id}_#{column.name.to_s}"
        "#{form.text_field :due_date, :size => 10} #{calendar_for(issue_id)}"
      elsif column.name.to_s == "priority"
        form.select column.name, options_from_collection_for_select(@project.issue_categories, :id, :name), {:include_blank => true}
      elsif column.name.to_s == "status"
        form.select column.name, options_from_collection_for_select(IssueStatus.find(:all), :id, :name), {:include_blank => true}
      elsif column.name.to_s == "tracker"
        form.select column.name, options_from_collection_for_select(@project.trackers, :id, :name), {:include_blank => true}
      else
        h(value)
      end 
      
    else
      
      if column.name.to_s == "priority"
        form.select column.name, options_from_collection_for_select(IssuePriority.find(:all), :id, :name, value.id), {:include_blank => true}
      elsif column.name.to_s == "status"
        form.select column.name, options_from_collection_for_select(IssueStatus.find(:all), :id, :name, value.id), {:include_blank => true}
      else
        h(value)
      end
    end
    
  end
  
  
  
  
  
  
end
