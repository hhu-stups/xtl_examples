
% -------------------------------------------
% MINIMAX - ALPHA/BETA ENCODING
% -------------------------------------------

% by Michael Leuschel and Philip Höfges

% YOU MUST DEFINE INTERFACE PREDICATES:
% game_move/3: game_move(Pos,Action,NewPos)
%   -> we assume the game ends when no moves are possible (there is no end/2 predicate)
% player(Pos,Player) with Player min or max: get the current player from the position
% utility/3: utility(Pos,Depth,Value): utility of a position at a given depth
% player_worst_outcome_with_depth(max/min,Depth,Val): worst utility value possible for given player and depth

% PROVIDES:
% minimax_value(Board,Depth,Value,Action,NewBoard)

:- use_module(library(random)).

/**
  player_worst_outcome_with_depth/3: player would loose
    +Player: which player?
    +Depth: current remaining depth?
    -Value: value of outcome
*/
% we take the depth into account so that Mini-Max will actually  move towards a check mate
% and not simply choose arbitrary moves staying in a winning configuration


% convenience predicate for trans/3 facts
minimax_auto_play(State,Depth,Value,Action,State2) :- 
   statistics(walltime,_),
   (minimax_value(State,Depth,Value,Action,State2)
    -> statistics(walltime,[_,Delta])%,
       %format('Move found by Minimax in ~w ms: ~w, value=~w~n',[Delta,Action,Value])
    ;  statistics(walltime,[_,Delta])%,
       %format('No move found by Minimax after ~w ms~n',[Delta])
  ).


minimax_value(Board,Depth,Value,Action,NewBoard) :-
  player_worst_outcome_with_depth(max,Depth,WW),
  player_worst_outcome_with_depth(min,Depth,BW),
  value(Board, (WW, BW), Depth, top_level,Value, Action, NewBoard).

/**
  value/6: return new value, move and board
    +Position: position information (min/max, Board)
    +Borders: (Alpha, Beta) for pruning
    +Depth: Maximal search depth
    +TopLevel: is equal to top_level if we are at the top-level of the tree
    -Value: return value
    -Action: description of the move
    -NextPosition: next position (max/min, Neues Board)
*/
value(Position, (Alpha, Beta), Depth, TopLevel,Value, Action, NextPosition) :-
  (Depth<1
   ->  utility(Position, Depth, Value),  %print(reached_limit(Value)),nl,
       Action=none, NextPosition=none
   ;   player(Position,Player),
       findall(Action/Succ, game_move(Position, Action, Succ), List), %print(list(Depth,Alpha/Beta,List)),nl,
       (List = [] 
        -> utility(Position, Depth, Value), %print(value(Depth,Value)),nl,
           Action=none, NextPosition=none
         ; player_worst_outcome_with_depth(Player, Depth,IV),
	 	   D2 is Depth-1,
		   (TopLevel=top_level -> random_permutation(List,RList) ; List=RList),
		   find_optimal_value(RList, Player, (Alpha, Beta), D2, IV, none/none, 
						   Value, ActionO/NextPositionO), %, print(optimal(Depth,Alpha/Beta,Value,Action)),nl
		    (TopLevel=top_level, ActionO=none % Player is losing, choose first random move
		     -> %format('Choosing random move for depth=~w and value=~w~n',[Depth,Value]),
		        RList = [Action/NextPosition|_]
		      ; Action/NextPosition = ActionO/NextPositionO
		    )
        )
  ).

/**
  update_value/7: update accumulator if possible value forces the update
    +Player: min or max
    +PVal: possible value
    +PS: action/position
    +Acc: old accumulated value
    +AS: old accumulated move
    -Upd: new accumulated value
    -US: new accumulated move
*/
update_value(max, PVal, PS, Acc, AS, UpdVal, US) :-
   (PVal > Acc % important not to use new value in case the minimax pruning triggered for last move: we do not want to take it !
    -> UpdVal = PVal, US = PS
    %;  Acc=none/none ->  UpdVal = Acc, US = PS  %Acc could be none/none and we could be in a loosing situation (so we return at least one move)
    ;  UpdVal = Acc, US = AS).
update_value(min, PVal, PS, Acc, AS, UpdVal, US) :-
   (PVal < Acc
    -> UpdVal = PVal, US = PS
    %; Acc=none/none ->  UpdVal = Acc, US = PS
    ; UpdVal = Acc, US = AS).

/**
  update_alpha_beta/4: update alpha beta for both player
    +Player: max or min
    +Borders: (Alpha, Beta) as before
    +Value: value to compare
    -NBorders: (NAlpha, NBeta) with new values
*/
update_alpha_beta(max, (Alpha, Beta), Value, (NAlpha, Beta)) :-
   NAlpha is max(Alpha, Value).
update_alpha_beta(min, (Alpha, Beta), Value, (Alpha, NBeta)) :-
   NBeta is min(Beta, Value).

/**
  find_optimal_value/8: find the optimal value for the player using minimax and alpha-beta
    +List: possible moves (findall results)
    +Player: Player to move
    +Boders: (Alpha, Beta)
    +Depth: Current search depth
    +AccValue: accumulator value
    +AccMove: accumulator move
    -ResValue: resulting value
    -ResMove: resulting move
*/

:- meta_predicate mnf(0).
mnf(C) :- (C -> true ; format('~n*** Call failed: ~w~n~n',[C]),trace,C).

find_optimal_value([], _, (_,_), _, ResValue, ResMove, ResValue, ResMove).
find_optimal_value([Action/Position|T], Player, (Alpha, Beta), Depth, AccValue, AccMove, ResValue, ResMove) :-
  %nl,print(examining_move(Player,Depth,Action,Alpha/Beta)),nl,
  value(Position, (Alpha, Beta), Depth, not_top_level,PVal, _, _),
  update_alpha_beta(Player, (Alpha, Beta), PVal, (NAlpha, NBeta)),
  update_value(Player, PVal, Action/Position, AccValue, AccMove, NewAccValue, NewAccMove),
  (NBeta =< NAlpha
  -> %print(prune(Player,Depth,Action,NAlpha,NBeta,val(NewAccValue),pval(PVal))),nl,
     ResMove = NewAccMove, % note : the last move may e.g. be the winning move found, triggering alpha-beta pruning
     ResValue = NewAccValue
  ;  %print(examine_result(Player,Depth,val(NewAccValue),NewAccMove,NAlpha/NBeta)),nl,nl,
     find_optimal_value(T, Player, (NAlpha, NBeta), Depth, NewAccValue, NewAccMove, ResValue, ResMove)).
