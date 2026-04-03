% -----------------------------------

% MCTS: Monte-Carlo Tree Search
% by Michael Leuschel
% May 2022

:- ensure_loaded(mcts_core).
:- ensure_loaded(nim).
tic :- ensure_loaded(tictactoe).

:- use_module(library(lists)).


run :- mcts_run(_).


% apply MCTS until we reach a final state
play :- start(Init), play(40000,Init).
play(_,State) :- pretty_print_node(State),
   terminal(State),!, 
   utility(State,Val), format('GAME OVER, Utility=~w~n',[Val]).
play(NrSims,State) :-
   statistics(walltime,[W1,_]),
   mcts_run(NrSims,leaf(State),Target),
   statistics(walltime,[W2,_]), DeltaW is W2-W1,
   format('Move with ~w simulations computed in ~w ms~n',[NrSims,DeltaW]),
   play(NrSims,Target).



% -------------

% DOT rendering
gen_dot(Tree) :-
   %trace,
   dot_graph_generator:gen_dot_graph('mcts_tree.dot',xtl_interface,mcts_node(Tree),mcts_trans(Tree)).
mcts_node(Tree,NodeID,none,NodeDesc,Shape,Style,Color) :-
   get_node(Tree,NodeID), %print(gen(NodeID)),nl,
   get_wins(Tree,W), get_visits(Tree,N),
   tools:ajoin([NodeID,',w=',W,',n=',N],NodeDesc),
   Shape=rectangle, Style=none, Color=black.
mcts_node(Tree,NodeID,none,NodeDesc,Shape,Style,Color) :-
   get_child(Tree,Child),
   mcts_node(Child,NodeID,none,NodeDesc,Shape,Style,Color).
mcts_trans(Tree,NodeID,Label,SuccID,Color,Style) :- Style=solid, Color=lightgray,
   Label = 'move',
   get_node(Tree,NodeID), 
   get_child(Tree,SuccID).
mcts_trans(Tree,NodeID,Label,SuccID,Color,Style) :-
   get_child(Tree,Child),
   mcts_trans(Child,NodeID,Label,SuccID,Color,Style).


% -------------

% requires pretty_print_node/1
print_tree(leaf(Node),Indent) :- indent(Indent), pretty_print_node(Node),nl.
print_tree(node(Node,Wins,Visits,Children),Indent) :-
     indent(Indent), pretty_print_node(Node),nl,
     length(Children,Childs),
     indent(Indent), format(' w=~w, n=~w, childs=~w~n',[Wins,Visits,Childs]),
     (member(C,Children), print_tree(C,s(Indent)), fail
      ; true).
indent(0).
indent(s(X)) :- print(' + '), indent(X).

