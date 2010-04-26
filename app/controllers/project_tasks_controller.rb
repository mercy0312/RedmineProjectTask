class ProjectTasksController < ApplicationController
  unloadable
  before_filter :find_project
  default_search_scope :issues
  before_filter :find_optional_project
  accept_key_auth :index, :update

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid
  
  helper :journals
  helper :projects
  include ProjectsHelper   
  helper :custom_fields
  include CustomFieldsHelper
  helper :issue_relations
  include IssueRelationsHelper
  helper :watchers
  include WatchersHelper
  helper :attachments
  include AttachmentsHelper
  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  helper :issues
  helper :timelog
  include Redmine::Export::PDF

  verify :method => :post,
         :only => :destroy,
         :render => { :nothing => true, :status => :method_not_allowed }
           
  def index
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update({'id' => "#{Issue.table_name}.id"}.merge(@query.available_columns.inject({}) {|h, c| h[c.name.to_s] = c.sortable; h}))
    
    if @query.valid?
      limit = case params[:format]
      when 'csv', 'pdf'
        Setting.issues_export_limit.to_i
      when 'atom'
        Setting.feeds_limit.to_i
      else
        per_page_option
      end
      
      @issue_count = @query.issue_count
      @issue_pages = Paginator.new self, @issue_count, limit, params['page']
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                              :order => sort_clause, 
                              :offset => @issue_pages.current.offset, 
                              :limit => limit)
      @issue_count_by_group = @query.issue_count_by_group
      
      respond_to do |format|
        format.html { render :layout => !request.xhr? }
        format.atom { render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
        format.csv  { send_data(issues_to_csv(@issues, @project), :type => 'text/csv; header=present', :filename => 'export.csv') }
        format.pdf  { send_data(issues_to_pdf(@issues, @project, @query), :type => 'application/pdf', :filename => 'export.pdf') }
      end
    else
      # Send html if the query is not valid
      render(:template => 'issues/index.rhtml', :layout => !request.xhr?)
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  
  
  def update
     #------------複数項目-------------
      issues = params[:issue]
      if issues
        issues.each_pair do |issue_id, issue_value|
          issue = Issue.find(issue_id)
          issue.update_attributes(issue_value)
        end
        flash[:notice] = "一括更新完了 "
      end
      
    #------------新項目-------------
     if params[:new] && params[:new][:subject]
        new_issue = Issue.new(params[:new])
        @project.issues << new_issue
        @project.save
        flash[:notice] = "新規追加しました。"
     end
     
     #-------------------------
     redirect_to :action => "index"
  end


    private
    
    # Filter for bulk operations
    def find_issues
      @issues = Issue.find_all_by_id(params[:id] || params[:ids])
      raise ActiveRecord::RecordNotFound if @issues.empty?
      projects = @issues.collect(&:project).compact.uniq
      if projects.size == 1
        @project = projects.first
      else
        # TODO: let users bulk edit/move/destroy issues from different projects
        render_error 'Can not bulk edit/move/destroy issues from different projects'
        return false
      end
    rescue ActiveRecord::RecordNotFound
      render_404
    end
    
    
    def find_project
      @project = Project.find(params[:project_id])
    end
    
    def find_optional_project
      @project = Project.find(params[:project_id]) unless params[:project_id].blank?
      allowed = User.current.allowed_to?({:controller => params[:controller], :action => params[:action]}, @project, :global => true)
      allowed ? true : deny_access
    rescue ActiveRecord::RecordNotFound
      render_404
    end
    
    # Retrieve query from session or build a new query
    def retrieve_query
      if !params[:query_id].blank?
        cond = "project_id IS NULL"
        cond << " OR project_id = #{@project.id}" if @project
        @query = Query.find(params[:query_id], :conditions => cond)
        @query.project = @project
        session[:query] = {:id => @query.id, :project_id => @query.project_id}
        sort_clear
      else
        if params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
          # Give it a name, required to be valid
          @query = Query.new(:name => "_")
          @query.project = @project
          if params[:fields] and params[:fields].is_a? Array
            params[:fields].each do |field|
              @query.add_filter(field, params[:operators][field], params[:values][field])
            end
          else
            @query.available_filters.keys.each do |field|
              @query.add_short_filter(field, params[field]) if params[field]
            end
          end
          @query.group_by = params[:group_by]
          @query.column_names = params[:query] && params[:query][:column_names]
          session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names}
        else
          @query = Query.find_by_id(session[:query][:id]) if session[:query][:id]
          @query ||= Query.new(:name => "_", :project => @project, :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
          @query.project = @project
        end
      end
    end
  
    # Rescues an invalid query statement. Just in case...
    def query_statement_invalid(exception)
      logger.error "Query::StatementInvalid: #{exception.message}" if logger
      session.delete(:query)
      sort_clear
      render_error "An error occurred while executing the query and has been logged. Please report this error to your Redmine administrator."
    end
  
end
