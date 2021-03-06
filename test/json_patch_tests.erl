%% Copyright (c) 2020-2021 Exograd SAS.
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
%% SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
%% IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

-module(json_patch_tests).

-include_lib("eunit/include/eunit.hrl").

parse_test_() ->
  Parse = fun json_patch:parse/1,
  [?_assertEqual([], Parse([])),
   ?_assertEqual([{add, [<<"a">>, <<"b">>, <<"c">>], [<<"foo">>, <<"bar">>]}],
                 Parse([#{<<"op">> => <<"add">>,
                          <<"path">> => <<"/a/b/c">>,
                          <<"value">> => [<<"foo">>, <<"bar">>]}])),
   ?_assertEqual([{remove, []}],
                 Parse([#{<<"op">> => <<"remove">>,
                          <<"path">> => <<"">>}])),
   ?_assertEqual([{replace, [<<"foo">>, <<"2">>], true}],
                 Parse([#{<<"op">> => <<"replace">>,
                          <<"path">> => <<"/foo/2">>,
                          <<"value">> => true}])),
   ?_assertEqual([{move, [<<"a">>], [<<"b">>]}],
                 Parse([#{<<"op">> => <<"move">>,
                          <<"path">> => <<"/b">>,
                          <<"from">> => <<"/a">>}])),
   ?_assertEqual([{copy, [<<"foo">>], []}],
                 Parse([#{<<"op">> => <<"copy">>,
                          <<"path">> => <<"">>,
                          <<"from">> => <<"/foo">>}])),
   ?_assertEqual([{test, [<<"a">>], #{<<"a">> => 1}}],
                 Parse([#{<<"op">> => <<"test">>,
                          <<"path">> => <<"/a">>,
                          <<"value">> => #{<<"a">> => 1}}])),
   ?_assertEqual([{remove, []},
                  {replace, [<<"foo">>, <<"2">>], true}],
                 Parse([#{<<"op">> => <<"remove">>,
                          <<"path">> => <<"">>},
                        #{<<"op">> => <<"replace">>,
                          <<"path">> => <<"/foo/2">>,
                          <<"value">> => true}])),
   ?_assertEqual({error, invalid_format},
                 Parse(42)),
   ?_assertEqual({error, invalid_format},
                 Parse([42])),
   ?_assertEqual({error, invalid_format},
                 Parse([[]])),
   ?_assertEqual({error, {missing_member, <<"op">>}},
                 Parse([#{}])),
   ?_assertEqual({error, {invalid_op, true}},
                 Parse([#{<<"op">> => true}])),
   ?_assertEqual({error, {invalid_op, <<"hello">>}},
                 Parse([#{<<"op">> => <<"hello">>}])),
   ?_assertEqual({error, {missing_member, <<"path">>}},
                 Parse([#{<<"op">> => <<"add">>}])),
   ?_assertEqual({error, {invalid_member, <<"path">>}},
                 Parse([#{<<"op">> => <<"add">>,
                          <<"path">> => 42}])),
   ?_assertEqual({error, {invalid_member, <<"path">>,
                          {invalid_pointer, invalid_format}}},
                 Parse([#{<<"op">> => <<"add">>,
                          <<"path">> => <<"foo">>}]))].

serialize_test_() ->
  Serialize = fun json_patch:serialize/1,
  [?_assertEqual([#{<<"op">> => <<"add">>,
                    <<"path">> => <<"/a/b/c">>,
                    <<"value">> => [<<"foo">>, <<"bar">>]}],
                 Serialize([{add, [<<"a">>, <<"b">>, <<"c">>],
                             [<<"foo">>, <<"bar">>]}])),
   ?_assertEqual([#{<<"op">> => <<"remove">>,
                    <<"path">> => <<"">>}],
                 Serialize([{remove, []}])),
   ?_assertEqual([#{<<"op">> => <<"replace">>,
                    <<"path">> => <<"/foo/2">>,
                    <<"value">> => true}],
                 Serialize([{replace, [<<"foo">>, <<"2">>], true}])),
   ?_assertEqual([#{<<"op">> => <<"move">>,
                    <<"path">> => <<"/b">>,
                    <<"from">> => <<"/a">>}],
                 Serialize([{move, [<<"a">>], [<<"b">>]}])),
   ?_assertEqual([#{<<"op">> => <<"copy">>,
                    <<"path">> => <<"">>,
                    <<"from">> => <<"/foo">>}],
                 Serialize([{copy, [<<"foo">>], []}])),
   ?_assertEqual([#{<<"op">> => <<"test">>,
                    <<"path">> => <<"/a">>,
                    <<"value">> => #{<<"a">> => 1}}],
                 Serialize([{test, [<<"a">>], #{<<"a">> => 1}}])),
   ?_assertEqual([#{<<"op">> => <<"remove">>,
                    <<"path">> => <<"">>},
                  #{<<"op">> => <<"replace">>,
                    <<"path">> => <<"/foo/2">>,
                    <<"value">> => true}],
                 Serialize([{remove, []},
                            {replace, [<<"foo">>, <<"2">>], true}]))].

execute_test_() ->
  [?_assertEqual([], json_patch:execute([], [])),
   ?_assertEqual(42, json_patch:execute([], 42))].

execute_add_test_() ->
  Execute = fun json_patch:execute/2,
  [?_assertEqual(42, Execute([{add, [], 42}], 1)),
   ?_assertEqual(42, Execute([{add, [], 42}], [])),
   ?_assertEqual(42, Execute([{add, [], 42}], [1, 2, 3])),
   ?_assertEqual([42], Execute([{add, [<<"0">>], 42}], [])),
   ?_assertEqual([42, 1, 2, 3], Execute([{add, [<<"0">>], 42}], [1, 2, 3])),
   ?_assertEqual([1, 42, 2, 3], Execute([{add, [<<"1">>], 42}], [1, 2, 3])),
   ?_assertEqual([1, 2, 42, 3], Execute([{add, [<<"2">>], 42}], [1, 2, 3])),
   ?_assertEqual([1, 2, 3, 42], Execute([{add, [<<"3">>], 42}], [1, 2, 3])),
   ?_assertEqual([1, 2, 3, 42], Execute([{add, [<<"-">>], 42}], [1, 2, 3])),
   ?_assertEqual(#{<<"a">> => 42}, Execute([{add, [<<"a">>], 42}], #{})),
   ?_assertEqual(#{<<"a">> => 42}, Execute([{add, [<<"a">>], 42}],
                                           #{<<"a">> => 1})),
   ?_assertEqual(#{<<"a">> => 42, <<"b">> => 2},
                 Execute([{add, [<<"a">>], 42}],
                         #{<<"a">> => 1, <<"b">> => 2}))].

execute_remove_test_() ->
  Execute = fun json_patch:execute/2,
  [?_assertEqual([2, 3], Execute([{remove, [<<"0">>]}], [1, 2, 3])),
   ?_assertEqual([1, 3], Execute([{remove, [<<"1">>]}], [1, 2, 3])),
   ?_assertEqual([1, 2], Execute([{remove, [<<"2">>]}], [1, 2, 3])),
   ?_assertEqual(#{}, Execute([{remove, [<<"a">>]}], #{<<"a">> => 1})),
   ?_assertEqual(#{<<"b">> => 2}, Execute([{remove, [<<"a">>]}],
                                          #{<<"a">> => 1, <<"b">> => 2}))].

execute_replace_test_() ->
  Execute = fun json_patch:execute/2,
  [?_assertEqual(42, Execute([{replace, [], 42}], 1)),
   ?_assertEqual([42, 2, 3], Execute([{replace, [<<"0">>], 42}], [1, 2, 3])),
   ?_assertEqual([1, 42, 3], Execute([{replace, [<<"1">>], 42}], [1, 2, 3])),
   ?_assertEqual([1, 2, 42], Execute([{replace, [<<"2">>], 42}], [1, 2, 3])),
   ?_assertEqual(#{<<"a">> => 42},
                 Execute([{replace, [<<"a">>], 42}], #{<<"a">> => 1})),
   ?_assertEqual(#{<<"a">> => 42, <<"b">> => 2},
                 Execute([{replace, [<<"a">>], 42}], #{<<"a">> => 1,
                                                       <<"b">> => 2}))].

execute_move_test_() ->
  Execute = fun json_patch:execute/2,
  [?_assertEqual([1, 2, 3], Execute([{move, [<<"0">>], [<<"0">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([2, 1, 3], Execute([{move, [<<"0">>], [<<"1">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([2, 3, 1], Execute([{move, [<<"0">>], [<<"2">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([2, 3, 1], Execute([{move, [<<"0">>], [<<"-">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([2, 1, 3], Execute([{move, [<<"1">>], [<<"0">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([1, 2, 3], Execute([{move, [<<"1">>], [<<"1">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([1, 3, 2], Execute([{move, [<<"1">>], [<<"2">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([1, 3, 2], Execute([{move, [<<"1">>], [<<"-">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([3, 1, 2], Execute([{move, [<<"2">>], [<<"0">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([1, 3, 2], Execute([{move, [<<"2">>], [<<"1">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([1, 2, 3], Execute([{move, [<<"2">>], [<<"2">>]}],
                                    [1, 2, 3])),
   ?_assertEqual([1, 2, 3], Execute([{move, [<<"2">>], [<<"-">>]}],
                                    [1, 2, 3])),
   ?_assertEqual(#{<<"a">> => 1},
                 Execute([{move, [<<"a">>], [<<"a">>]}],
                         #{<<"a">> => 1})),
   ?_assertEqual(#{<<"b">> => 1},
                 Execute([{move, [<<"a">>], [<<"b">>]}],
                         #{<<"a">> => 1, <<"b">> => 2})),
   ?_assertEqual(#{<<"b">> => 2, <<"c">> => 1},
                 Execute([{move, [<<"a">>], [<<"c">>]}],
                         #{<<"a">> => 1, <<"b">> => 2})),
   ?_assertEqual(#{<<"a">> => 1},
                 Execute([{move, [<<"a">>, <<"b">>], [<<"a">>]}],
                         #{<<"a">> => #{<<"b">> => 1}}))].

execute_copy_test_() ->
  Execute = fun json_patch:execute/2,
  [?_assertEqual(42, Execute([{copy, [], []}], 42)),
   ?_assertEqual([1, 1, 2, 3], Execute([{copy, [<<"0">>], [<<"0">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 1, 2, 3], Execute([{copy, [<<"0">>], [<<"1">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 2, 1, 3], Execute([{copy, [<<"0">>], [<<"2">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 2, 3, 1], Execute([{copy, [<<"0">>], [<<"3">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 2, 3, 1], Execute([{copy, [<<"0">>], [<<"-">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([2, 1, 2, 3], Execute([{copy, [<<"1">>], [<<"0">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 2, 2, 3], Execute([{copy, [<<"1">>], [<<"1">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 2, 2, 3], Execute([{copy, [<<"1">>], [<<"2">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 2, 3, 2], Execute([{copy, [<<"1">>], [<<"3">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 2, 3, 2], Execute([{copy, [<<"1">>], [<<"-">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([3, 1, 2, 3], Execute([{copy, [<<"2">>], [<<"0">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 3, 2, 3], Execute([{copy, [<<"2">>], [<<"1">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 2, 3, 3], Execute([{copy, [<<"2">>], [<<"2">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 2, 3, 3], Execute([{copy, [<<"2">>], [<<"3">>]}],
                                       [1, 2, 3])),
   ?_assertEqual([1, 2, 3, 3], Execute([{copy, [<<"2">>], [<<"-">>]}],
                                       [1, 2, 3])),
   ?_assertEqual(#{<<"a">> => 1},
                 Execute([{copy, [<<"a">>], [<<"a">>]}],
                                          #{<<"a">> => 1})),
   ?_assertEqual(#{<<"a">> => 1, <<"b">> => 1},
                 Execute([{copy, [<<"a">>], [<<"b">>]}],
                         #{<<"a">> => 1, <<"b">> => 2})),
   ?_assertEqual(#{<<"a">> => 1, <<"b">> => 2, <<"c">> => 1},
                 Execute([{copy, [<<"a">>], [<<"c">>]}],
                         #{<<"a">> => 1, <<"b">> => 2})),
   ?_assertEqual(#{<<"a">> => #{<<"b">> => #{<<"b">> => 1}}},
                 Execute([{copy, [<<"a">>], [<<"a">>, <<"b">>]}],
                                          #{<<"a">> => #{<<"b">> => 1}})),
   ?_assertEqual(#{<<"a">> => 1},
                 Execute([{copy, [<<"a">>, <<"b">>], [<<"a">>]}],
                                          #{<<"a">> => #{<<"b">> => 1}}))].

execute_test_test_() ->
  Execute = fun json_patch:execute/2,
  [?_assertEqual(42, Execute([{test, [], 42}], 42)),
   ?_assertEqual(1, Execute([{test, [<<"0">>], 1}], [1, 2, 3])),
   ?_assertEqual(null, Execute([{test, [<<"a">>, <<"b">>], null}],
                               #{<<"a">> => #{<<"b">> => null}})),
   ?_assertMatch({error, _}, Execute([{test, [<<"a">>, <<"c">>],
                                       null}],
                                     #{<<"a">> => #{}})),
   ?_assertMatch({error, _}, Execute([{test, [<<"a">>, <<"c">>],
                                       null}],
                                     #{})),
   ?_assertMatch({error, _}, Execute([{test, [<<"a">>, <<"c">>], null}], []))].
