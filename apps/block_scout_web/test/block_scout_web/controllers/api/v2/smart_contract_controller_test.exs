defmodule BlockScoutWeb.API.V2.SmartContractControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  alias BlockScoutWeb.AddressContractView
  alias BlockScoutWeb.Models.UserFromAuth
  alias Explorer.Chain.Address

  describe "/smart-contracts/{address_hash}" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/smart-contracts/#{address.hash}")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/smart-contracts/0x")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get smart-contract", %{conn: conn} do
      target_contract = insert(:smart_contract)

      tx =
        insert(:transaction,
          created_contract_address_hash: target_contract.address_hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block()

      correct_response = %{
        "verified_twin_address_hash" => nil,
        "is_verified" => true,
        "is_changed_bytecode" => false,
        "is_partially_verified" => target_contract.partially_verified,
        "is_fully_verified" => true,
        "is_verified_via_sourcify" => target_contract.verified_via_sourcify,
        "is_vyper_contract" => target_contract.is_vyper_contract,
        "minimal_proxy_address_hash" => nil,
        "sourcify_repo_url" =>
          if(target_contract.verified_via_sourcify,
            do: AddressContractView.sourcify_repo_url(target_contract.address_hash, target_contract.partially_verified)
          ),
        "can_be_visualized_via_sol2uml" => false,
        "name" => target_contract && target_contract.name,
        "compiler_version" => target_contract.compiler_version,
        "optimization_enabled" => if(target_contract.is_vyper_contract, do: nil, else: target_contract.optimization),
        "optimization_runs" => target_contract.optimization_runs,
        "evm_version" => target_contract.evm_version,
        "verified_at" => target_contract.inserted_at |> to_string() |> String.replace(" ", "T"),
        "source_code" => target_contract.contract_source_code,
        "file_path" => target_contract.file_path,
        "additional_sources" => [],
        "compiler_settings" => target_contract.compiler_settings,
        "external_libraries" => target_contract.external_libraries,
        "constructor_args" => target_contract.constructor_arguments,
        "decoded_constructor_args" => nil,
        "is_self_destructed" => false,
        "deployed_bytecode" =>
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "creation_bytecode" =>
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
      }

      blockchain_get_code_mock()
      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(target_contract.address_hash)}")
      response = json_response(request, 200)

      assert ^correct_response = Map.drop(response, ["abi"])
      assert response["abi"] == target_contract.abi
    end
  end

  describe "/smart-contracts/{address_hash}/methods-read" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/smart-contracts/#{address.hash}/methods-read")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/smart-contracts/0x/methods-read")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get read-methods", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      blockchain_eth_call_mock()

      request = get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-read")
      assert response = json_response(request, 200)

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "outputs" => [
                 %{
                   "type" => "address",
                   "name" => "",
                   "internalType" => "address",
                   "value" => "0xfffffffffffffffffffffffffffffffffffffffe"
                 }
               ],
               "name" => "getCaller",
               "inputs" => [],
               "method_id" => "ab470f05"
             } in response

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool", "value" => ""}],
               "name" => "isWhitelist",
               "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}],
               "method_id" => "c683630d"
             } in response
    end
  end

  describe "/smart-contracts/{address_hash}/query-read-method" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request =
        post(conn, "/api/v2/smart-contracts/#{address.hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request =
        post(conn, "/api/v2/smart-contracts/0x/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "query-read-method", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x0000000000000000000000000000000000000000000000000000000000000001"
             }
           ]}
        end
      )

      target_contract = insert(:smart_contract, abi: abi)

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{
               "is_error" => false,
               "result" => %{"names" => ["bool"], "output" => [%{"type" => "bool", "value" => true}]}
             } == response
    end

    test "query-read-method returns error 1", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          {:ok, [%{id: id, jsonrpc: "2.0", error: %{code: "12345", message: "Error message"}}]}
        end
      )

      target_contract = insert(:smart_contract, abi: abi)

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{"is_error" => true, "result" => %{"code" => "12345", "message" => "Error message"}} == response
    end

    test "query-read-method returns error 2", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          {:error, {:bad_gateway, "request_url"}}
        end
      )

      target_contract = insert(:smart_contract, abi: abi)

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)
      assert %{"is_error" => true, "result" => %{"error" => "Bad gateway"}} == response
    end

    test "query-read-method returns error 3", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          raise FunctionClauseError
        end
      )

      target_contract = insert(:smart_contract, abi: abi)

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{"is_error" => true, "result" => %{"error" => "no function clause matches"}} == response
    end
  end

  describe "/smart-contracts/{address_hash}/methods-write" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/smart-contracts/#{address.hash}/methods-write")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/smart-contracts/0x/methods-write")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get write-methods", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      request = get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-write")
      assert response = json_response(request, 200)

      assert [
               %{
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "outputs" => [],
                 "name" => "disableWhitelist",
                 "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
               }
             ] == response
    end
  end

  describe "/smart-contracts/{address_hash}/methods-[write/read] & query read method custom abi" do
    setup %{conn: conn} do
      auth = build(:auth)

      {:ok, user} = UserFromAuth.find_or_create(auth)

      {:ok, conn: Plug.Test.init_test_session(conn, current_user: user)}
    end

    test "get write method from custom abi", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      custom_abi = :custom_abi |> build() |> Map.replace("abi", abi)

      conn
      |> post(
        "/api/account/v1/user/custom_abis",
        custom_abi
      )

      request =
        get(conn, "/api/v2/smart-contracts/#{custom_abi["contract_address_hash"]}/methods-write", %{
          "is_custom_abi" => true
        })

      assert response = json_response(request, 200)

      assert [
               %{
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "outputs" => [],
                 "name" => "disableWhitelist",
                 "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
               }
             ] == response
    end

    test "get read method from custom abi", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      custom_abi = :custom_abi |> build() |> Map.replace("abi", abi)

      conn
      |> post(
        "/api/account/v1/user/custom_abis",
        custom_abi
      )

      blockchain_eth_call_mock()

      request =
        get(conn, "/api/v2/smart-contracts/#{custom_abi["contract_address_hash"]}/methods-read", %{
          "is_custom_abi" => true
        })

      assert response = json_response(request, 200)

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "outputs" => [
                 %{
                   "type" => "address",
                   "name" => "",
                   "internalType" => "address",
                   "value" => "0xfffffffffffffffffffffffffffffffffffffffe"
                 }
               ],
               "name" => "getCaller",
               "inputs" => [],
               "method_id" => "ab470f05"
             } in response

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool", "value" => ""}],
               "name" => "isWhitelist",
               "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}],
               "method_id" => "c683630d"
             } in response
    end

    test "query read method", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      custom_abi = :custom_abi |> build() |> Map.replace("abi", abi)

      conn
      |> post(
        "/api/account/v1/user/custom_abis",
        custom_abi
      )

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x0000000000000000000000000000000000000000000000000000000000000001"
             }
           ]}
        end
      )

      request =
        post(conn, "/api/v2/smart-contracts/#{custom_abi["contract_address_hash"]}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "is_custom_abi" => true,
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{
               "is_error" => false,
               "result" => %{"names" => ["bool"], "output" => [%{"type" => "bool", "value" => true}]}
             } == response
    end
  end

  defp blockchain_get_code_mock do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: "eth_getCode", params: [_, _]}], _options ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result:
               "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
           }
         ]}
      end
    )
  end

  defp blockchain_eth_call_mock do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: "eth_call", params: params}], opts ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result: "0x000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"
           }
         ]}
      end
    )
  end

  defp blockchain_eth_call_mock do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: "eth_call", params: params}], opts ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result: "0x000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"
           }
         ]}
      end
    )
  end

  defp debug(value, key) do
    require Logger
    Logger.configure(truncate: :infinity)
    Logger.info(key)
    Logger.info(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
    value
  end
end