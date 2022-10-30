<h1 align="center">
  <br>
  <img src="/logo.svg?raw=true" alt="Cards logo" width="256">
  <br>
</h1>

<h4 align="center">🃏 A lightning network inspired Starknet Game</h4>

# Why GasLessLiar?
Blockchain allows decentralized interactions between users following contract rules, but blockchain interactions are expensive and slow. GasLessLiar is a proof of concept of a Game which allows honest users to avoid interacting with the chain. The idea is pretty simple: this contract allows you to prove if your opponent is malicious and will punish him. And because he would be punished if he was malicious, he will probably stay honest, and your interactions will therefore stay off-chain. To check our peer to peer client, [Click here](https://github.com/Gaseless-liar/liar-game).

# What's the game?
Alice plays against Bob
1) A and B both draw 4 secret cards.
2) A draws a public card and put it on the stack.
3) A puts a card face down with a value higher than the public card (he can lie) or draws a card.
4) B can accuse him of lying, if that's not the case, restart 3) with A=B and B=A. If A has emptied his hand, he wins.
5) A reveals his card, if he lied, he takes all the cards from the stack in his hand. If he said the truth, B does.
6) If one player has emptied his hand, he wins the game. If the stack is empty, the player with the smallest hand wins. Otherwise, restart from 2) with A=B and B=A.

# Diving deeper in how it works

GasLessLiar can be seen as a channel between two players. One player could use this channel to transfer a game state to the other. If the transition from the previous state to this state is correct, the second player will accept it. If it is incorrect or if the second player doesn't answer, the first user can give to the contract his last valid known state. The other user will have to call the contract with a valid transition to a new state. If he doesn't, the first user will be able to trigger a win after a delay (5 minutes here).
To open a channel, two users need to generate temporary keypairs. They will share public keys and one will call the contract with a Game configuration (game_id, public_keys and bet amount). Both users will then to join the gane and lock their bet into the contract. At the end of the game, if everything went well, a single signature from the loser saying "I lost" will allow the winner to redeem the funds.

# States (not up to date)
### States

Every state must come with a signature from its creator. Usual verifications include game_id = game_id and prev_state_hash = hash(prev_state).

#### Round Init

##### State 1 (A)

- game_id

- h1 = hash(s1, 0)

- type = 1

###### Info

> s1, a secret random value by A

##### State 2 (B)
- game_id
- Prev state hash
- s2
- H1
- type = 2

###### Info

> s2, a public random value by B

###### Verification (A)

- h1 = old(h1)

##### State 3 (A)

- game_id
- Prev state hash
- s1
- starting_card
- type = 3

###### Info

>  starting_card = hash(s1, old(s2))

###### Verification

> hash(s1) = old(h1)
>
> starting_card = hash(s1, old(s2))

### Draw

####  Turn State (A) (R3 | T) -> (T | R1)

- game_id

- Prev state hash

- starting_card

- placed_A_cards_fingerprints

- placed_B_cards_fingerprints

- type = 4

- hashes of A public cards and salts

- hashes of B public cards and salts

- Secrets of cards drawn by B

- Secrets of cards drawn by A

- Action

  
###### Info

>  F, fingerprint of card drawn by A si action = 1 (pioche), else nothing

###### Verification

> - Action = 1 | 0
> - placed_cards_fingerprints = [] si old(type) = 3, sinon F :: placed_cards_fingerprints 
> - 
>
> - _ = _

#### Round State

  - Prev_round_hash
  - Game_id
  - Last_turn_hash
  - Shared_A_cards
  - Shared_B_cards

