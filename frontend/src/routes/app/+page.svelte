<script lang="ts">
  import type { Abi, AccountInterface } from "starknet";
  import { get } from "svelte/store";
  import Table from "$lib/components/Table.svelte";
  import Card from "$lib/components/Card.svelte";
  import { deposits } from "$lib/data/deposits";
  import { activity } from "$lib/data/activity";
  import truncateAddress from "$lib/utils/truncateAddress";
  import balance from "$lib/stores/balance";
  import DepositForm from "$lib/components/DepositForm.svelte";
  import { contract, account } from "$lib/svark";
  import contractABI from "$lib/data/starknetContractAbi.json";

  contract("starknet", {
    contractAddress:
      "0x0092bf28825b91673695eb6b34f009e1194be3a359aac1a88db54e592e6cfe66",
    abi: contractABI as Abi,
    providerOrAccount: get(account).account as AccountInterface,
  });
</script>

{#if !$balance}
  <DepositForm />
{:else}
  <h2 class="mb-8">Activity</h2>
  <div class="w-fit mb-10 flex flex-col gap-3">
    <h3 class="flex items-center gap-4">
      New Proposals
      <span
        class="inline-flex text-14 bg-orange rounded-full w-6 h-6 justify-center items-center"
        >{activity.length}</span
      >
    </h3>
    {#each activity as { author, title }}
      <Card>
        <div>
          <h4 class="mb-2">{title}</h4>
          <p class="text-14">by {truncateAddress(author)}</p>
        </div>
      </Card>
    {/each}
  </div>

  <div class="mx-auto mb-10">
    <h3 class="mb-4">My Deposits</h3>
    <Table
      color="lightPurple"
      labels={["Timestamp", "Transaction Hash", "Amount"]}
      rows={deposits
        .map(({ timestamp, transaction_hash: hash, amount }) => [
          new Date(timestamp).toLocaleDateString("en-UK", {
            day: "numeric",
            month: "numeric",
            year: "numeric",
          }),
          hash,
          String(amount).concat(" ETH"),
        ])
        .reverse()}
    />
  </div>
{/if}
