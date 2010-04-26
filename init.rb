require 'redmine'

Redmine::Plugin.register :redmine_project_task do
  name 'Redmine Project Task plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  
  permission :project_tasks, {:project_tasks => [:index, :update]}
  menu :project_menu, :project_tasks, { :controller => 'project_tasks', :action => 'index' }, :caption => :project_task, :last => true, :param => :project_id
  
end
