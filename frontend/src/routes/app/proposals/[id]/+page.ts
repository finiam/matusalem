import { error } from "@sveltejs/kit";
import { get } from "svelte/store";
import proposals from "$lib/stores/proposals";

export function load({ params: { id } }: { params: { id: string } }) {
  /* const proposal = proposals.find((item) => item.id === id); */
  const data = get(proposals).find((item: any) => item.id === id);

  if (data) {
    return {
      proposal: data,
    };
  }

  throw error(404, "Not found");
}
