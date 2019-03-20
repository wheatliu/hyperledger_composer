#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Feature: CompleteSettlement

    Background:
        Given I have deployed the business network definition ..
        And I have added the following participants of type org.clearing.BankingParticipant
            | bankingId | bankingName | workingCurrency | fundBalance |
            | bank1     | Bank One    | USD             | 1000000     |
            | bank2     | Bank Two    | EURO            | 1000000     |
        And I have issued the participant org.clearing.BankingParticipant#bank1 with the identity bank1
        And I have issued the participant org.clearing.BankingParticipant#bank2 with the identity bank2
        And I have added the following assets
            """
            [
            {"$class":"org.clearing.TransferRequest",
            "requestId":"xferid1",
            "details":{"$class":"org.clearing.Transfer","currency":"USD","amount":1000,"fromAccount":"111111","toAccount":"222222"},
            "fromBankState":"PRE_PROCESS_COMPLETE",
            "toBankState":"PRE_PROCESS_COMPLETE",
            "state":"PRE_PROCESS_COMPLETE",
            "fromBank":"bank1",
            "toBank":"bank2"},

            {"$class":"org.clearing.TransferRequest",
            "requestId":"xferid2",
            "details":{"$class":"org.clearing.Transfer","currency":"EURO","amount":1000,"fromAccount":"333333","toAccount":"444444"},
            "fromBankState":"PRE_PROCESS_COMPLETE",
            "toBankState":"PRE_PROCESS_COMPLETE",
            "state":"PRE_PROCESS_COMPLETE",
            "fromBank":"bank2",
            "toBank":"bank1"},

            {"$class":"org.clearing.BatchTransferRequest",
            "batchId":"batch1:bank1-bank2",
            "settlement":{"$class":"org.clearing.Settlement",
            "amount":333.33333333333326,
            "currency":"USD",
            "creditorBank":"org.clearing.BankingParticipant#bank1",
            "debtorBank":"org.clearing.BankingParticipant#bank2"},
            "state":"READY_TO_SETTLE",
            "parties":["org.clearing.BankingParticipant#bank1","org.clearing.BankingParticipant#bank2"],
            "transferRequests":["org.clearing.TransferRequest#xferid1","org.clearing.TransferRequest#xferid2"]}
            ]
            """

    Scenario: Bank 1 completes the settlement
        When I use the identity bank1
        And I submit the following transaction
            """
            [
            {"$class":"org.clearing.CompleteSettlement",
            "batchId":"batch1:bank1-bank2",
            "usdRates": [
            {"$class":"org.clearing.UsdExchangeRate","to":"EURO","rate":0.75},
            {"$class":"org.clearing.UsdExchangeRate","to":"STERLING","rate":1.75}]}
            ]
            """
        Then I should have the following assets
            """
            [
            {"$class":"org.clearing.TransferRequest",
            "requestId":"xferid1",
            "details":{"$class":"org.clearing.Transfer","currency":"USD","amount":1000,"fromAccount":"111111","toAccount":"222222"},
            "fromBankState":"PRE_PROCESS_COMPLETE",
            "toBankState":"PRE_PROCESS_COMPLETE",
            "state":"PRE_PROCESS_COMPLETE",
            "fromBank":"bank1",
            "toBank":"bank2"},

            {"$class":"org.clearing.TransferRequest",
            "requestId":"xferid2",
            "details":{"$class":"org.clearing.Transfer","currency":"EURO","amount":1000,"fromAccount":"333333","toAccount":"444444"},
            "fromBankState":"PRE_PROCESS_COMPLETE",
            "toBankState":"PRE_PROCESS_COMPLETE",
            "state":"PRE_PROCESS_COMPLETE",
            "fromBank":"bank2",
            "toBank":"bank1"},

            {"$class":"org.clearing.BatchTransferRequest",
            "batchId":"batch1:bank1-bank2",
            "settlement":{"$class":"org.clearing.Settlement",
            "amount":333.33333333333326,
            "currency":"USD",
            "creditorBank":"org.clearing.BankingParticipant#bank1",
            "debtorBank":"org.clearing.BankingParticipant#bank2"},
            "state":"PENDING_POST_PROCESS",
            "parties":["org.clearing.BankingParticipant#bank1","org.clearing.BankingParticipant#bank2"],
            "transferRequests":["org.clearing.TransferRequest#xferid1","org.clearing.TransferRequest#xferid2"]}
            ]
            """
        And I should have the following participants of type org.clearing.BankingParticipant
            | bankingId | bankingName | workingCurrency | fundBalance |
            | bank1     | Bank One    | USD             | 1000333     |
            | bank2     | Bank Two    | EURO            | 999750      |