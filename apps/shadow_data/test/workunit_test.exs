defmodule ShadowDate.JobsTest do
  use ExUnit.Case

  alias ShadowData.DictionaryStreamWorkUnit
  alias ShadowData.DictionaryWorkUnit
  alias ShadowData.WorkUnitParser
  alias ShadowData.BruteforceWorkUnit

  test "Dictionary job division" do
    jobs = [%DictionaryStreamWorkUnit{stream: ["a", "b", "c", "d", "e", "f"]}]

    {current, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert %DictionaryWorkUnit{names: ["a", "b"]} = current

    {current, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert %DictionaryWorkUnit{names: ["c", "d"]} = current

    {current, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert %DictionaryWorkUnit{names: ["e", "f"]} = current

    assert :empty == WorkUnitParser.take_work(jobs, 2)
  end

  test "Bruteforce division with limit" do
    jobs = [%BruteforceWorkUnit{begin: 100, last: 104, charset: [1,2,3]}]

    {%BruteforceWorkUnit{begin: b, last: l, charset: charset}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 100 && l == 101 && charset == [1,2,3]

    {%BruteforceWorkUnit{begin: b, last: l}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 102 && l == 103 && charset == [1,2,3]

    {%BruteforceWorkUnit{begin: b, last: l}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 104 && l == 104 && charset == [1,2,3]

    assert :empty == WorkUnitParser.take_work(jobs, 2)
  end

  test "Bruteforce division with infinity" do
    jobs = [%BruteforceWorkUnit{begin: 100, last: :inf, charset: [1,2,3]}]

    {%BruteforceWorkUnit{begin: b, last: l, charset: charset}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 100 && l == 101 && charset == [1,2,3]

    {%BruteforceWorkUnit{begin: b, last: l, charset: charset}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 102 && l == 103 && charset == [1,2,3]

    {%BruteforceWorkUnit{begin: b, last: l, charset: charset}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 104 && l == 105 && charset == [1,2,3]

    {%BruteforceWorkUnit{begin: b, last: l, charset: charset}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 106 && l == 107 && charset == [1,2,3]

    assert :empty != WorkUnitParser.take_work(jobs, 2)
  end

  test "Dictionary coalesce with bruteforce" do
    jobs = [%DictionaryStreamWorkUnit{stream: ["a", "b", "c", "d", "e", "f"]}, %BruteforceWorkUnit{begin: 100, last: :inf, charset: [1,2,3,4]}]

    # Test dictionary
    {current, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert %DictionaryWorkUnit{names: ["a", "b"]} = current

    {current, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert %DictionaryWorkUnit{names: ["c", "d"]} = current

    {current, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert %DictionaryWorkUnit{names: ["e", "f"]} = current

    # Should transition to a bruteforce...

    {%BruteforceWorkUnit{begin: b, last: l, charset: charset}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 100 && l == 101 && charset == [1,2,3,4]

    {%BruteforceWorkUnit{begin: b, last: l, charset: charset}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 102 && l == 103 && charset == [1,2,3,4]

    {%BruteforceWorkUnit{begin: b, last: l, charset: charset}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 104 && l == 105 && charset == [1,2,3,4]

    {%BruteforceWorkUnit{begin: b, last: l, charset: charset}, jobs} = WorkUnitParser.take_work(jobs, 2)
    assert b == 106 && l == 107 && charset == [1,2,3,4]

    assert :empty != WorkUnitParser.take_work(jobs, 2)
  end
end
