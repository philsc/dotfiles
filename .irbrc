require "rubygems"
require "wirble"

# This colorizes the IRB output a bit
Wirble.init
Wirble.colorize

# Dummy hash and array so I don't have to create one every
# time I start irb. Now I can just access HASH and ARRAY.
HASH = {
    one: 1,
    three: 3,
    four: 'four',
    five: 'xxxxx',
}

ARRAY = [1, 2, 5, 19, 23, 8, 'foo', 'bar']
