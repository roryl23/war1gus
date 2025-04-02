module War1gusAI

using Base.Threads
using Format

include("model.jl")

# TODO: this function should receive a filename from War1gus and write there
function write_to_outfile(content::String)
  open("/tmp/War1gusAI.out", "w") do file
    write(file, content)
  end
end

function async_stdin_reader(
  s::Channel{String},  # stdin channel
)
  while true
    if eof(stdin)
      write_to_outfile("War1gusAI: received EOF on stdin, exiting...")
      exit()
    end
    line = readline(stdin)
    put!(s, line)
    yield()
  end
end

@kwdef mutable struct Game
  state::String=""
  function Game(state::String)
    new(state)
  end
end

function evaluator(
  game::Game,
  op::Dict,  # options
  o::Channel{String},  # output channel
)
  output = format("{1}", "function pwnEnemies() return AiSleep(10000) end")
  put!(o, output)
  return
end

function process_gamestate(
  tokens::Vector{SubString{String}},
  op::Dict,  # options
  o::Channel{String},  # output channel
)::Task
  game = Game(String(tokens[2]))
  return @spawn evaluator(
    game,
    op,
    o,
  )
end

function process_setoption(
  tokens::Vector{SubString{String}},
  options::Dict,
)::Dict
  if length(tokens) > 2 && tokens[2] == "name"
    option_name = tokens[3]
    option_value = nothing
    if length(tokens) > 4 && tokens[4] == "value"
      option_value = join(tokens[5:end], " ")
    end
    options[option_name] = option_value
  else
    write_to_outfile("Invalid setoption command")
  end
  return options
end

function process_command(
  line::String,
  op::Dict,  # options
  t::Task,  # engine task
  o::Channel{String},  # output channel
)::Tuple{Vector{SubString{String}}, Any}
  tokens = split(line)
  if length(tokens) == 0
    return tokens, nothing
  end
  cmd_type = tokens[1]

  if ==("gamestate", cmd_type)
    return tokens, process_gamestate(tokens, op, o)
  elseif ==("setoption", cmd_type)
    return tokens, process_setoption(tokens, op)
  elseif ==("stop", cmd_type)
    wait(t)
  else
    write_to_outfile("War1gusAI: unknown command: $cmd_type")
  end

  return tokens, nothing
end

function real_main()
  # initializations
  stdin_channel = Channel{String}(1)
  output_channel = Channel{String}(Inf)
  engine_task = Task(())
  options = Dict()

  @spawn async_stdin_reader(
    stdin_channel,
  )
  # main loop
  while true
    if isready(stdin_channel)
      line = take!(stdin_channel)
      command, result = process_command(
        line,
        options,
        engine_task,
        output_channel,
      )
      if <(0, length(command))
        if ==(command[1], "gamestate") && ==(Task, typeof(result))
          engine_task = result
        elseif ==(command[1], "setoption") && ==(Dict, typeof(result))
          options = result
        end
      end
    end

    if isready(output_channel)
      write_to_outfile(take!(output_channel))
    end

    yield()
  end
end

function julia_main()::Cint
  try
    real_main()
  catch
    Base.invokelatest(Base.display_error, Base.catch_stack())
    return 1
  end
  return 0
end

end  # module