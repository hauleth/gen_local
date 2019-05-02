%% @author Łukasz Niemier
%% @doc
%% Run `gen_server' modules in synchronous way for easier testing.
%%
%% == Example ==
%%
%% ```
%% {ok, State} = gen_local:start(my_server, []).
%%
%% {ok, Reply, State1} = gen_local:call(State, do_thing).
%% '''
%% @end
-module(gen_local).

%% API exports
-export([start/2,
         call/2,
         cast/2,
         send/2]).

-export_type([state/0]).

-record(state, {state, module}).

%% @type state().
%% Store for simulated process state.
%% @end
-opaque state() :: #state{}.

%%====================================================================
%% API functions
%%====================================================================

%% @doc
%% Fake startup process of given `gen_server' module in synchronous way.
%%
%% In short it will run `Module:init(Args)' and then will react in similar way
%% to the `gen_server:start/3' function.
%% @end
-spec start(module(), term()) -> {ok, state()} | ignore | {stopped, term()}.
start(Module, Args) ->
    case Module:init(Args) of
        {ok, State} ->
            {ok, #state{state = State, module = Module}};

        {ok, State, {continue, Msg}} ->
            handle_continue(Msg, #state{state = State, module = Module});

        {ok, State, _Timeout} ->
            {ok, #state{state = State, module = Module}};

        ignore ->
            ignore;

        {stop, Reason} ->
            {stopped, Reason}
    end.

%% @doc
%% Fake `gen_server:call/2' on faked `gen_server' process.
%%
%% It will try to always return value, so there is no timeout support.  It
%% handles `gen_server:reply/2' calls whenever there is `noreply' answer.
%% @end
-spec call(S, Msg::term()) -> {ok, Reply, S}
                              | {stopped, Reason, State::term()}
                              | {stopped, Reason, Reply, State::term()}
                                      when Reply :: term(),
                                           Reason :: term(),
                                           S :: state().
call(#state{module = Module, state = State} = S, Msg) ->
    Tag = make_ref(),
    case Module:handle_call(Msg, {self(), Tag}, State) of
        {reply, Reply, NewState} ->
            {ok, Reply, S#state{state = NewState}};

        {reply, Reply, NewState, {continue, Cont}} ->
            case handle_continue(Cont, S#state{state = NewState}) of
                {ok, NewNewState} -> {ok, Reply, NewNewState};
                Other -> Other
            end;

        {reply, Reply, NewState, _Timeout} ->
            {ok, Reply, S#state{state = NewState}};

        {noreply, NewState} ->
            async_reply(Tag, S#state{state = NewState});

        {noreply, NewState, {continue, Cont}} ->
            case handle_continue(Cont, S#state{state = NewState}) of
                {ok, NewNewState} ->
                    async_reply(Tag, S#state{state = NewNewState});

                Other ->
                    Other
            end;

        {noreply, NewState, _Timeout} ->
            async_reply(Tag, S#state{state = NewState});

        {stop, Reason, NewState} ->
            {stopped, Reason, NewState};

        {stop, Reason, Reply, NewState} ->
            {stopped, Reason, Reply, NewState}
    end.

%% @doc
%% Fake `gen_server:cast/2' on faked `gen_server' process.
%% @end
-spec cast(S, Msg::term()) -> {ok, S}
                              | {stopped, Reason::term(), State::term()}
                                when S::state().
cast(S, Msg) ->
    handle_reply(fake_call(S, handle_cast, Msg), S).

%% @doc
%% Fake sending message to faked `gen_server' process.
%% @end
-spec send(S, Msg::term()) -> {ok, S}
                              | {stopped, Reason::term(), State::term()}
                                when S::state().
send(S, Msg) ->
    handle_reply(fake_call(S, handle_info, Msg), S).

%%====================================================================
%% Internal functions
%%====================================================================

-spec fake_call(state(), atom(), term()) -> term().
fake_call(#state{state = State, module = Module}, Callback, Msg) ->
    Module:Callback(Msg, State).

-spec handle_continue(term(), S) -> {ok, S} | {stopped, term(), term()}.
handle_continue(Msg, S) ->
    handle_reply(fake_call(S, handle_continue, Msg), S).

async_reply(Tag, State) ->
    receive
        {Tag, Reply} -> {ok, Reply, State}
    end.

-spec handle_reply(Result, S) -> {ok, S} | {stopped, term(), term()}
                                   when Result :: {noreply, term()}
                                        | {noreply, term(), {continue, term()}}
                                        | {noreply, term(), timeout()}
                                        | {stop, term(), term()}.
handle_reply({noreply, NewState}, S) ->
    {ok, S#state{state = NewState}};
handle_reply({noreply, NewState, {continue, Msg}}, S) ->
    handle_continue(Msg, S#state{state = NewState});
handle_reply({noreply, NewState, _Timeout}, S) ->
    {ok, S#state{state = NewState}};
handle_reply({stop, Reason, NewState}, _S) ->
    {stopped, Reason, NewState}.
