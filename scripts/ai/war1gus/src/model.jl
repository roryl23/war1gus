using Transformers
using Transformers.Layers
using Flux

# Define the vocabulary
const VOCAB = [
  # Function names
  "AiAttackWithForce", "AiCheckForce",
  "AiForce", "AiForceRole",
  "AiResearch", "AiSet", "AiSetCollect", "AiSetReserve",
  "AiUpgradeTo", "AiWait", "AiWaitForce",
  # Numbers
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
  # Unit types
  "footman", "archer", "peasant", "knight",
  # Resources
  "gold", "lumber",
  # Roles
  "attack", "defend",
  # Research IDs
  "upgrade-sword1", "upgrade-arrow1",
  # Special tokens
  "<SEP>", "<EOS>"
]
const VOCAB_SIZE = length(VOCAB)
const VOCAB_DICT = Dict(word => i for (i, word) in enumerate(VOCAB))
const IDX_TO_TOKEN = Dict(i => word for (i, word) in enumerate(VOCAB))

struct StratagusTokenizer
  vocab::Dict{String, Int}
end

function encode(t::StratagusTokenizer, text::String)
  words = split(text)
  return [get(t.vocab, word, t.vocab["<EOS>"]) for word in words]
end

function decode(t::StratagusTokenizer, ids::Vector{Int})
  return join([IDX_TO_TOKEN[id] for id in ids if 1 ≤ id ≤ VOCAB_SIZE], " ")
end

const tokenizer = StratagusTokenizer(VOCAB_DICT)

const EMBED_DIM = 64    # Embedding dimension
const NUM_HEADS = 4     # Number of attention heads
const HIDDEN_DIM = 128  # Feedforward hidden dimension
const NUM_LAYERS = 2    # Number of transformer layers

embedding = Embed(EMBED_DIM, VOCAB_SIZE)
attention = Transformers.Layers.SelfAttention(NUM_HEADS, HIDDEN_DIM)
ffn = Chain(
  Dense(EMBED_DIM, HIDDEN_DIM, relu),
  Dense(HIDDEN_DIM, EMBED_DIM)
)
encoder_layer = TransformerBlock(NUM_HEADS, HIDDEN_DIM)
output_layer = Dense(EMBED_DIM, VOCAB_SIZE)

function generate_command(input::String; max_length::Int=5)
  input_ids = encode(tokenizer, input)
  output_ids = copy(input_ids)

  for _ in 1:max_length
    embedded = embedding(input_ids)
    transformed = ffn(embedded)
    logits = output_layer(transformed')'
    probs = softmax(logits, dims=2)
    next_id = argmax(probs[end, :])
    push!(output_ids, next_id)
    if next_id == VOCAB_DICT["<EOS>"]
      break
    end
  end

  return decode(tokenizer, output_ids)
end