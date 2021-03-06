#
# Copyright (C) 2014 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require_relative '../api_spec_helper'
require_relative '../../lti_spec_helper'
require_dependency "lti/lti_apps_controller"

module Lti
  describe LtiAppsController, type: :request do
    include LtiSpecHelper

    let(:account) { Account.create }
    describe '#launch_definitions' do

      before do
        tp = create_tool_proxy
        tp.bindings.create(context: account)
        rh = create_resource_handler(tp)
        @mh = create_message_handler(rh)
        @external_tool = new_valid_external_tool(account)
      end

      it 'returns a list of launch definitions for a context and placements' do
        resource_tool = new_valid_external_tool(account, true)
        course_with_teacher(active_all: true, user: user_with_pseudonym, account: account)
        json = api_call(:get, "/api/v1/courses/#{@course.id}/lti_apps/launch_definitions",
                 {controller: 'lti/lti_apps', action: 'launch_definitions', format: 'json',
                  placements: %w(resource_selection), course_id: @course.id.to_s})
        expect(json.detect {|j| j['definition_type'] == resource_tool.class.name && j['definition_id'] == resource_tool.id}).not_to be_nil
        expect(json.detect {|j| j['definition_type'] == @external_tool.class.name && j['definition_id'] == @external_tool.id}).to be_nil
      end

      it 'works for a teacher even without lti_add_edit permissions' do
        course_with_teacher(active_all: true, user: user_with_pseudonym, account: account)
        account.role_overrides.create!(:permission => "lti_add_edit", :enabled => false, :role => teacher_role)
        json = api_call(:get, "/api/v1/courses/#{@course.id}/lti_apps/launch_definitions",
          {controller: 'lti/lti_apps', action: 'launch_definitions', format: 'json', course_id: @course.id.to_s})
        expect(json.count).to eq 1
        expect(json.detect {|j| j['definition_type'] == @external_tool.class.name && j['definition_id'] == @external_tool.id}).not_to be_nil
      end

      it 'returns unauthorized for a student' do
        course_with_student(active_all: true, user: user_with_pseudonym, account: account)

        api_call(:get, "/api/v1/courses/#{@course.id}/lti_apps/launch_definitions",
          {controller: 'lti/lti_apps', action: 'launch_definitions', format: 'json', course_id: @course.id.to_s})

        expect(response.status).to eq 401
      end

      it 'returns global_navigation launches for a student' do
        course_with_student(active_all: true, user: user_with_pseudonym, account: account)

        tool = new_valid_external_tool(@course.root_account)
        tool.global_navigation = {
          :text => "Global Nav"
        }
        tool.save!

        json = api_call(:get, "/api/v1/courses/#{@course.id}/lti_apps/launch_definitions",
          {controller: 'lti/lti_apps', action: 'launch_definitions', format: 'json', course_id: @course.id.to_s},
          placements: ['global_navigation'])

        expect(response.status).to eq 200
        expect(json.count).to eq 1
        expect(json.first['definition_id']).to eq tool.id
        # expect(json.detect {|j| j.key?('name') && j.key?('domain')}).not_to be_nil
      end

      it 'paginates the launch definitions' do
        5.times { |_| new_valid_external_tool(account) }
        course_with_teacher(active_all: true, user: user_with_pseudonym, account: account)
        json = api_call(:get, "/api/v1/courses/#{@course.id}/lti_apps/launch_definitions?per_page=3",
                        {controller: 'lti/lti_apps', action: 'launch_definitions', format: 'json',
                         placements: Lti::ResourcePlacement::DEFAULT_PLACEMENTS, course_id: @course.id.to_s, per_page: '3'})

        json_next = follow_pagination_link('next', {
          controller: 'lti/lti_apps',
          action: 'launch_definitions',
          format: 'json',
          course_id: @course.id.to_s
        })
        expect(json.count).to eq 3
        expect(json_next.count).to eq 3
        json
      end
    end

    describe '#index' do

      before do
        @tp = create_tool_proxy
        @tp.bindings.create(context: account)
        @external_tool = new_valid_external_tool(account)
      end

      it 'returns a list of app definitions for a context' do
        course_with_teacher(active_all: true, user: user_with_pseudonym, account: account)
        json = api_call(:get, "/api/v1/courses/#{@course.id}/lti_apps",
                        {controller: 'lti/lti_apps', action: 'index', format: 'json',
                         course_id: @course.id.to_s})
        expect(json.select {|j| j['app_type'] == @tp.class.name && j['app_id'] == @tp.id.to_s}).not_to be_nil
        expect(json.select {|j| j['app_type'] == @external_tool.class.name && j['app_id'] == @external_tool.id.to_s}).not_to be_nil
      end

      it 'paginates the launch definitions' do
        5.times { |_| new_valid_external_tool(account) }
        course_with_teacher(active_all: true, user: user_with_pseudonym, account: account)
        json = api_call(:get, "/api/v1/courses/#{@course.id}/lti_apps?per_page=3",
                        {controller: 'lti/lti_apps', action: 'index', format: 'json',
                         course_id: @course.id.to_s, per_page: '3'})

        json_next = follow_pagination_link('next', {
          controller: 'lti/lti_apps',
          action: 'index',
          format: 'json',
          course_id: @course.id.to_s
        })
        expect(json.count).to eq 3
        expect(json_next.count).to eq 3
        json
      end

    end


  end
end
