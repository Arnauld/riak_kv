%% -------------------------------------------------------------------
%%
%% riak_kv_wm_ts_util: utility functions for riak_kv_wm_timeseries* resources.
%%
%% Copyright (c) 2016 Basho Technologies, Inc.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
-module(riak_kv_wm_ts_util).


-export([table_from_request/1]).
-export([utf8_to_binary/1]).
-export([flat_format/2]).
-export([set_text_resp_header/2]).
-export([set_error_message/3]).
-export([set_json_response/2]).

-export([authorize/3]).


%% @private
table_from_request(RD) ->
    utf8_to_binary(
      mochiweb_util:unquote(
        wrq:path_info(table, RD))).

%% move to util module.
utf8_to_binary(S) ->
    unicode:characters_to_binary(S, utf8, utf8).

flat_format(Format, Args) ->
    lists:flatten(io_lib:format(Format, Args)).

set_text_resp_header(IoList, RD) ->
       wrq:set_resp_header(
       "Content-Type", "text/plain", wrq:append_to_response_body(IoList,RD)).

set_error_message(Format, Args, RD) ->
    set_text_resp_header(flat_format(Format, Args), RD).

set_json_response(Json, RD) ->
     wrq:set_resp_header("Content-Type", "application/json",
                         wrq:append_to_response_body(Json, RD)).



authorize(Call, Table, RD) ->
     case riak_api_web_security:is_authorized(RD) of
        false ->
             {error, "Basic realm=\"Riak\""};
        {true, undefined} -> %% @todo: why is this returned during testing?
             ok;
        {true, SecContext} ->
            case riak_core_security:check_permission(
                   {riak_kv_ts_util:api_call_to_perm(Call), Table}, SecContext) of
                 {false, Error, _} ->
                    {error, utf8_to_binary(Error)};
                 _ ->
                    ok
            end;
        insecure ->
             ErrorMsg = "Security is enabled and Riak does not" ++
                 " accept credentials over HTTP. Try HTTPS instead.",
             Resp = set_text_resp_header(ErrorMsg, RD),
             {insecure, {halt, 426}, Resp}
     end.