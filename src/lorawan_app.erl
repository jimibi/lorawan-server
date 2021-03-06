%
% Copyright (c) 2016-2017 Petr Gotthard <petr.gotthard@centrum.cz>
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(lorawan_app).
-behaviour(application).

-export([start/0]).
-export([start/2, stop/1]).

-include_lib("lorawan_server_api/include/lorawan_application.hrl").
-include("lorawan.hrl").

start() ->
    {ok, _Started} = application:ensure_all_started(lorawan_server).

start(_Type, _Args) ->
    ok = ensure_erlang_version(19),
    lorawan_db:ensure_tables(),
    {ok, _} = timer:apply_interval(3600*1000, lorawan_db, trim_tables, []),

    {ok, Handlers} = lorawan_handler:init(),
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/applications/[:name]", lorawan_admin_applications, []},
            {"/users/[:name]", lorawan_admin_database,
                [users, user, record_info(fields, user)]},
            {"/gateways/[:mac]", lorawan_admin_database,
                [gateways, gateway, record_info(fields, gateway)]},
            {"/multicast_channels/[:devaddr]", lorawan_admin_database,
                [multicast_groups, multicast_group, record_info(fields, multicast_group)]},
            {"/devices/[:deveui]", lorawan_admin_database,
                [devices, device, record_info(fields, device)]},
            {"/nodes/[:devaddr]", lorawan_admin_database,
                [links, link, record_info(fields, link)]},
            {"/ignored_nodes/[:devaddr]", lorawan_admin_database,
                [ignored_links, ignored_link, record_info(fields, ignored_link)]},
            {"/txframes/[:frid]", lorawan_admin_database,
                [txframes, txframe, record_info(fields, txframe)]},
            {"/rxframes/[:frid]", lorawan_admin_database,
                [rxframes, rxframe, record_info(fields, rxframe)]},
            {"/handlers/[:appid]", lorawan_admin_database,
                [handlers, handler, record_info(fields, handler)]},
            {"/connectors/[:connid]", lorawan_admin_database,
                [connectors, connector, record_info(fields, connector)]},
            {"/events/[:evid]", lorawan_admin_database,
                [events, event, record_info(fields, event)]},
            {"/upload", lorawan_admin_upload, []},
            {"/gwgraph/:mac", lorawan_admin_gwgraph, []},
            {"/rgraph/:devaddr", lorawan_admin_rxgraph, [rgraph]},
            {"/qgraph/:devaddr", lorawan_admin_rxgraph, [qgraph]},
            {"/devstat/:devaddr", lorawan_admin_devstat, []},
            {"/", cowboy_static, {priv_file, lorawan_server, "root.html"}},
            {"/admin", cowboy_static, {priv_file, lorawan_server, "admin/index.html"}},
            {"/admin/[...]", cowboy_static, {priv_dir, lorawan_server, "admin"}}
        ]++Handlers}
    ]),
    case application:get_env(http_admin_listen) of
        undefined ->
            ok;
        {ok, undefined} ->
            ok;
        {ok, HttpOpts} ->
            {ok, _} = cowboy:start_clear(http, HttpOpts,
                #{env => #{dispatch => Dispatch}})
    end,
    case application:get_env(http_admin_listen_ssl) of
        undefined ->
            ok;
        {ok, undefined} ->
            ok;
        {ok, SslOpts} ->
            {ok, _} = cowboy:start_tls(https, SslOpts,
                #{env => #{dispatch => Dispatch}})
    end,
    lorawan_sup:start_link().

stop(_State) ->
    ok = cowboy:stop_listener(http),
    ok.

ensure_erlang_version(Min) ->
    case list_to_integer(erlang:system_info(otp_release)) of
        Num when Num >= Min -> ok;
        _Else -> {error, prerequisite_failed}
    end.

% end of file
