import unittest
import garden

suite "garden":
  test "hello returns expected greeting":
    check hello() == "hello from garden"

  test "version present":
    check projectVersion == "0.0.1"
