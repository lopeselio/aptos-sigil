# Guilds module

Lightweight **per-publisher** guilds: name, leader, member list (max 100). One guild membership per player address per publisher. No NFT transfers—use for teams, seasons, or matchmaking metadata.

## Flow

1. **`init_guilds`** (publisher, once)
2. **`create_guild`** — player signer; args: `address:PUBLISHER`, `string:"Guild Name"`
3. **`join_guild`** — player signer; `address:PUBLISHER`, `u64:guild_id`
4. **`leave_guild`** — player signer; `address:PUBLISHER` (leader leaving promotes the next member; last member leaving deletes the guild)
5. **`disband_guild`** — publisher or delegated role; `address:PUBLISHER`, `u64:guild_id`

## CLI examples

Initialize (publisher):

```bash
aptos move run --profile publisher \
  --function-id 'PUB::guilds::init_guilds' \
  --assume-yes
```

Create guild (player is founder + leader):

```bash
aptos move run --profile player1 \
  --function-id 'PUB::guilds::create_guild' \
  --args address:PUB string:"Night Owls" \
  --assume-yes
```

Second player joins guild `0`:

```bash
aptos move run --profile player2 \
  --function-id 'PUB::guilds::join_guild' \
  --args address:PUB u64:0 \
  --assume-yes
```

## Views

- `guilds::is_initialized(publisher)`
- `guilds::guild_count(publisher)` — next guild id (count created)
- `guilds::player_guild_id(publisher, player)` → `(in_guild, guild_id)`
- `guilds::get_guild(publisher, guild_id)` → `(exists, name, leader, member_count)`
