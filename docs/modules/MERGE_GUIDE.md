# Merge (crafting) module

Publisher-defined **recipes** over abstract **`item_id: u64`** quantities. This MVP tracks per-player inventory on-chain; it does **not** burn Token Objects automatically. Pair with your game server or a future version that debits real FAs/NFTs.

## Flow

1. **`init_merge`** (publisher signer, once)
2. **`register_recipe`** — `actor` + `publisher` address (same pattern as achievements). Consumes `input_qty` of `input_item_id`, produces `output_qty` of `output_item_id`.
3. **`grant_items`** — publisher (or role) credits a player’s inventory (loot, quest reward, IAP sync).
4. **`execute_merge`** — player signer; `publisher` as first `--args` address; `recipe_id`.

## CLI examples

Publisher registers a recipe (3× item `1` → 1× item `2`):

```bash
aptos move run --profile publisher \
  --function-id 'PUB::merge::register_recipe' \
  --args \
    address:PUB \
    u64:1 \
    u64:3 \
    u64:2 \
    u64:1 \
  --assume-yes
```

Grant 10 of item `1` to a player:

```bash
aptos move run --profile publisher \
  --function-id 'PUB::merge::grant_items' \
  --args address:PUB address:PLAYER u64:1 u64:10 \
  --assume-yes
```

Player runs recipe `0`:

```bash
aptos move run --profile player \
  --function-id 'PUB::merge::execute_merge' \
  --args address:PUB u64:0 \
  --assume-yes
```

## Views

- `merge::recipe_count(publisher)`
- `merge::get_recipe(publisher, recipe_id)` → `(exists, input_item_id, input_qty, output_item_id, output_qty)`
- `merge::get_item_qty(publisher, player, item_id)`

## Errors (common)

| Code | Meaning |
|------|---------|
| 2 | Recipe not found |
| 3 | Not enough input items |
| 4 | No permission (roles / not owner) |
