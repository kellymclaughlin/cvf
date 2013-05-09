-module cvf_storage.

-export([
         config/2,
         config/4,
         create_container/2,
         delete_container/2,
         list_containers/1,
         list_objects/2,
         get_object/3,
         put_object/4,
         delete_object/3]
       ).

-record(config, {
          storage_url :: string(),
          token :: string(),
          proxy_host :: string(),
          proxy_port :: pos_integer()
         }).

-type config() :: #config{}.
-type response() :: ok |
                    {ok, response_headers(), response_body()} |
                    {error, term()}.
-type list_response() :: {ok, response_headers(), [string()]} |
                         {error, term()}.

%% ===================================================================
%% Public API
%% ===================================================================

-spec config(string(), string()) -> config().
config(StorageUrl, Token) ->
    #config{storage_url=format_url(StorageUrl),
            token=Token
           }.

-spec config(string(), string(), string(), pos_integer()) -> config().
config(StorageUrl, Token, ProxyHost, ProxyPort) ->
    #config{storage_url=format_url(StorageUrl),
            token=Token,
            proxy_host=ProxyHost,
            proxy_port=ProxyPort
           }.

-spec list_containers(config()) -> list_response().
list_containers(#config{storage_url=URL,
                        token=Token,
                        proxy_host=undefined,
                        proxy_port=undefined}) ->
    list_response(http_req(get, URL, [auth_token_header(Token)], [], []));
list_containers(#config{storage_url=URL,
                        token=Token,
                        proxy_host=ProxyHost,
                        proxy_port=ProxyPort}) ->
    ProxyOpts = proxy_options(ProxyHost, ProxyPort),
    list_response(http_req(get, URL, [auth_token_header(Token)], [], ProxyOpts)).

-spec create_container(string(), config()) -> response().
create_container(Name, #config{storage_url=StorageUrl,
                               token=Token,
                               proxy_host=undefined,
                               proxy_port=undefined}) ->
    URL = make_url(StorageUrl, Name),
    response(http_req(put, URL, [auth_token_header(Token), {"User-Agent", "cvf in yo ass"},{"Content-Length", ""}], [], []));
create_container(Name, #config{storage_url=StorageUrl,
                               token=Token,
                               proxy_host=ProxyHost,
                               proxy_port=ProxyPort}) ->
    ProxyOpts = proxy_options(ProxyHost, ProxyPort),
    URL = make_url(StorageUrl, Name),
    response(http_req(put, URL, [auth_token_header(Token)], [], ProxyOpts)).

-spec delete_container(string(), config()) -> response().
delete_container(Name, #config{storage_url=StorageUrl,
                               token=Token,
                               proxy_host=undefined,
                               proxy_port=undefined}) ->
    URL = make_url(StorageUrl, Name),
    response(http_req(delete, URL, [auth_token_header(Token)], [], []));
delete_container(Name, #config{storage_url=StorageUrl,
                               token=Token,
                               proxy_host=ProxyHost,
                               proxy_port=ProxyPort}) ->
    ProxyOpts = proxy_options(ProxyHost, ProxyPort),
    URL = make_url(StorageUrl, Name),
    response(http_req(delete, URL, [auth_token_header(Token)], [], ProxyOpts)).

-spec list_objects(string(), config()) -> list_response().
list_objects(Bucket, #config{storage_url=StorageUrl,
                             token=Token,
                             proxy_host=undefined,
                             proxy_port=undefined}) ->
    URL = make_url(StorageUrl, Bucket),
    list_response(http_req(get, URL, [auth_token_header(Token)], [], []));
list_objects(Bucket, #config{storage_url=StorageUrl,
                             token=Token,
                             proxy_host=ProxyHost,
                             proxy_port=ProxyPort}) ->
    ProxyOpts = proxy_options(ProxyHost, ProxyPort),
    URL = make_url(StorageUrl, Bucket),
    list_response(http_req(get, URL, [auth_token_header(Token)], [], ProxyOpts)).

-spec put_object(string(), string(), req_body(), config()) -> response().
put_object(Bucket, Key, Data, #config{storage_url=StorageUrl,
                                      token=Token,
                                      proxy_host=undefined,
                                      proxy_port=undefined}) ->
    URL = make_url(StorageUrl, Bucket, Key),
    response(http_req(put, URL, [auth_token_header(Token)], Data, []));
put_object(Bucket, Key, Data, #config{storage_url=StorageUrl,
                                      token=Token,
                                      proxy_host=ProxyHost,
                                      proxy_port=ProxyPort}) ->
    ProxyOpts = proxy_options(ProxyHost, ProxyPort),
    URL = make_url(StorageUrl, Bucket, Key),
    response(http_req(put, URL, [auth_token_header(Token)], Data, ProxyOpts)).

-spec get_object(string(), string(), config()) -> response().
get_object(Bucket, Key, #config{storage_url=StorageUrl,
                                token=Token,
                                proxy_host=undefined,
                                proxy_port=undefined}) ->
    URL = make_url(StorageUrl, Bucket, Key),
    response(http_req(get, URL, [auth_token_header(Token)], [], []), true);
get_object(Bucket, Key, #config{storage_url=StorageUrl,
                                token=Token,
                                proxy_host=ProxyHost,
                                proxy_port=ProxyPort}) ->
    ProxyOpts = proxy_options(ProxyHost, ProxyPort),
    URL = make_url(StorageUrl, Bucket, Key),
    response(http_req(get, URL, [auth_token_header(Token)], [], ProxyOpts), true).

-spec delete_object(string(), string(), config()) -> response().
delete_object(Bucket, Key, #config{storage_url=StorageUrl,
                                   token=Token,
                                   proxy_host=undefined,
                                   proxy_port=undefined}) ->
    URL = make_url(StorageUrl, Bucket, Key),
    response(http_req(delete, URL, [auth_token_header(Token)], [], []));
delete_object(Bucket, Key, #config{storage_url=StorageUrl,
                                   token=Token,
                                   proxy_host=ProxyHost,
                                   proxy_port=ProxyPort}) ->
    ProxyOpts = proxy_options(ProxyHost, ProxyPort),
    URL = make_url(StorageUrl, Bucket, Key),
    response(http_req(delete, URL, [auth_token_header(Token)], [], ProxyOpts)).

%% ===================================================================
%% Internal functions
%% ===================================================================

-type method() :: get | head | delete | put | post.
-type req_body() :: string() | binary().
-type response_body() :: string().
-type response_headers() :: [{string(), string()}].
-type http_response() :: {ok, string(), response_headers(), response_body()} |
                         {error, term()}.

-spec http_req(method(), string(), proplists:proplist(), req_body(), proplists:proplist())
              -> http_response().
http_req(Method, URL, Headers, Body, Options) ->
    ibrowse:send_req(URL, Headers, Method, Body, Options).

-spec response(http_response()) -> response().
response(Response) ->
    response(Response, false).

-spec response(http_response(), boolean()) -> response().
response({ok, _, Headers, Body}, true) ->
    {ok, Headers, Body};
response({ok, _, _, _}, false) ->
    ok;
response({error, _}=Error, _) ->
    Error.

-spec list_response(http_response()) -> list_response().
list_response({ok, Status, Headers, Body}) ->
    ok_list_response(list_to_integer(Status), Headers, Body);
list_response({error, _}=Error) ->
    Error.

-spec ok_list_response(pos_integer(), response_headers(), response_body()) ->
                              list_response().
ok_list_response(Status, Headers, Body)
    when Status >= 200, Status < 400 ->
    {ok, Headers, string:tokens(Body, "\n")};
ok_list_response(Status, _, Body) ->
    {error, {Status, Body}}.

-spec auth_token_header(string()) -> {string(), string()}.
auth_token_header(Token) ->
    {"X-Auth-Token", Token}.

-spec proxy_options(undefined | string(), undefined | pos_integer())
                   -> proplists:proplist().
proxy_options(undefined, Port) ->
    [{proxy_host, "localhost"}, {proxy_port, Port}];
proxy_options(Host, undefined) ->
    [{proxy_host, Host}, {proxy_port, 80}];
proxy_options(Host, Port) ->
    [{proxy_host, Host}, {proxy_port, Port}].

-spec make_url(string(), string()) -> string().
make_url(Base, Container) ->
    Base ++ Container.

-spec make_url(string(), string(), string()) -> string().
make_url(Base, Container, Object) ->
    lists:flatten([Base, Container, "/", Object]).

-spec format_url(string()) -> string().
format_url(Url) ->
    format_url(Url, has_trailing_slash(Url)).

-spec format_url(string(), boolean()) -> string().
format_url(Url, true) ->
    Url;
format_url(Url, false) ->
    Url ++ "/".

-spec has_trailing_slash(string()) -> boolean().
has_trailing_slash(Url) ->
    lists:last(Url) =:= "/".
