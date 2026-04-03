% -----------------------------------

% MCTS: Monte-Carlo Tree Search
% by Michael Leuschel
% May 2022

% requires: 
% start/1
% game_move/3 and random_game_move/3
% utility/2 defined for terminal states only; values should be between 0 (loss) and 1 (win)
% player/2  (min or max)

% convenience predicate for trans/3 facts
mcts_auto_play(State,SimRuns,Action,State2) :- 
  mcts_incr_auto_play(State,SimRuns,Action,State2,leaf(State),_FinalTree).

% a version where we can provide the initial MCTS Tree for incremental reuse
mcts_incr_auto_play(State,SimRuns,Action,State2,Tree,FinalTree) :- 
   statistics(walltime,_),
   (mcts_run(SimRuns,Tree,FinalTree,State2)
    -> statistics(walltime,[_,Delta]),
       game_move(State,Action,State2),
       format('Move found by MCTS in ~w ms: ~w~n',[Delta,Action])
   ).


mcts_run(Target) :- start(Init), mcts_run(10000,leaf(Init),_,Target).
mcts_run(Nr,Tree,FinalTree,Target) :- mcts_loop(Nr,Tree,FinalTree),
   get_best_mcts_move(FinalTree,_Visits,Target).
   %get_node(FinalTree,From),
   %format('Best move from ~w is to ~w (~w visits)~n',[From,Target,Visits]).
   %print_tree(Tree,0).
   %gen_dot(Tree).
   

% run MCTS for a single initial tree with Nr iterations
mcts_loop(Nr,Tree,FinalTree) :- Nr>1,!,
   mcts(Tree,_,NewTree),
   N1 is Nr-1,
   mcts_loop(N1,NewTree,FinalTree).
mcts_loop(_,Tree,Tree). %format('Final MCTS Tree : ~w~n',[Tree]),
   


:- use_module(library(lists),[maplist/3, max_member/2, reverse/2]).

% find a direct child for a given (successor) state of the root state
% can be used to update the tree after a move was made
get_mcts_child_for_state(node(_,_,_,Children),State,Child) :-
   member(Child,Children),
   get_node(Child,State),!.
get_mcts_child_for_state(Tree,State,Child) :-
   print(cannot_get_child_for_state(State,Tree)),nl,
   Child=leaf(State). % create a new root

get_best_mcts_move(node(_,_,_,Children),MaxV,Target) :-
    maplist(get_visits,Children,Visits),
    max_member(MaxV,Visits),
    member(N,Children),
    get_visits(N,MaxV),
    get_node(N,Target).

invert_win(0,R) :- !, R=1.
invert_win(1,R) :- !, R=0.
invert_win(0.5,R) :- !, R=0.5.
invert_win(R,R1) :- trace, R1 is 1-R.

%mcts(X,_,_) :- print(mcts(X)),nl,fail.
mcts(node(State,Wins,Visits,Childs),OuterWin,node(State,Wins1,V1,Childs1)) :-
   V1 is Visits+1,
   (Childs=[]
    ->  % the node has no children; simulate it, i.e., compute the utility value
       Childs1=[],
       simulate_for_parent(State,_,OuterWin)
    ;  LogNi is log(V1),
       (select_best_ucb_child(Childs,State,LogNi,Child,Childs1,Child1) -> true
         ; print(selection_failed),nl,trace),
       mcts(Child,ChildWin,Child1),
       invert_win(ChildWin,OuterWin)
   ),
   % backpropagate:
   Wins1 is Wins+OuterWin.
   %print(update(State,OuterWin,child(Child))),nl.
mcts(leaf(State),Wins,node(State,Wins,1,Childs)) :-
   findall(leaf(C),game_move(State,_,C),Childs),
   simulate_for_parent(State,_Val,Wins).
   %print(expanded(State,Wins,Val,Childs)),nl.

select_best_ucb_child([C],_,_,C,[C1],C1) :- !. % no need to compute when there is a single child
select_best_ucb_child([Child1|Children],_Parent,LogNi,Child,NewChildren,NewChild) :- !,
   ucb(Child1,LogNi,UCB1),
   get_max_ucb(Children,LogNi,UCB1,Child1,[],Child,Rest),
   NewChildren = [NewChild|Rest].

%select_best_ucb_child(Children,_Parent,LogNi,Child,NewChildren,NewChild) :- % old version with sort/maplist
%   maplist(create_ucb_node(LogNi),Children,UC),
%   sort(UC,UCS), reverse(UCS,RUCS), % this can be done more efficiently
%   maplist(project,RUCS,SortedChildren),
%   SortedChildren = [Child|Rest],
%   NewChildren = [NewChild|Rest].

% select BestChild with maximal UCB value
get_max_ucb([],_,_,Child,Rest,Child,Rest).
get_max_ucb([Node|T],LogNi,CurMax,BestChildSoFar,RestSoFar,BestChild,Rest) :-
   ucb(Node,LogNi,UCB),
   UCB>CurMax, % we have a new best node
   !,
   get_max_ucb(T,LogNi,UCB,Node,[BestChildSoFar|RestSoFar],BestChild,Rest).
get_max_ucb([Node|T],LogNi,CurMax,BestChildSoFar,RestSoFar,BestChild,Rest) :-
   get_max_ucb(T,LogNi,CurMax,BestChildSoFar,[Node|RestSoFar],BestChild,Rest).
   

% helper functions for maplist:
project(ucb(_,Node),Node).
create_ucb_node(LogNi,Node,ucb(UCB,Node)) :- ucb(Node,LogNi,UCB).
get_visits(node(_,_,V,_),V).
get_visits(leaf(_),0).
get_wins(node(_,W,_,_),W).
get_wins(leaf(_),0).
get_node(node(N,_,_,_),N).
get_node(leaf(N),N).
get_child(node(_,_,_,C),Child) :- nonvar(C),member(Child,C).

% compute UCB value for a node
ucb(leaf(_),_,Res) :- Res = 1000000.
ucb(node(_,Wins,Visits,_),LogNi,Res) :- 
   (Visits=0 -> Res = 10000 
   ; Res is (Wins/Visits) + sqrt(2.0 * LogNi / Visits)
   ).

% simulate and report win as viewed by the parent of X
simulate_for_parent(X,Val,Res) :- simulate_random(X,Val),
    (player(X,max), Val<0 -> Res = 1
     ; \+ player(X,max), Val>0 -> Res = 1
     ; Val=0 -> Res = 0.5 % draw
     ; Res = 0). %  loss

:- use_module(library(random),[random_member/2, random_member/2, random_permutation/2]).
simulate_random(X,Res) :- 
    utility(X,R),!,Res=R. % , pretty_print_node(X), nl, print(Res),nl,nl.
simulate_random(X,Res) :-
    random_game_move(X,_,Z),!, % use my_random_game_move if not provided by game
    simulate_random(Z,Res).

% use if the game does not provide random_game_move
my_random_game_move(X,move,Z) :-
    findall(Y,game_move(X,_,Y),List),
    random_select(Z,List,_).

terminal(State) :- utility(State,_).
other_player(min,max).
other_player(max,min).


