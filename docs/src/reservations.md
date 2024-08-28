# Reservations

[Reservations](https://docs.aws.amazon.com/braket/latest/developerguide/braket-reservations.html) grant exclusive access to a specific quantum device for a predetermined time slot. This control over execution windows offers several advantages to users:

  * **Predictability:** Users have guaranteed knowledge of precisely when their tasks will be executed, eliminating scheduling uncertainties.
  * **Prioritization:** During the reservation window, the user's workloads take precedence over others, avoiding queueing delays and potential bottlenecks.
  * **Efficiency:**  The cost is based solely on the reserved duration, irrespective of the number of tasks the user runs within that window.

# Why Use Reservations?

In certain scenarios, reservations provide significant benefits over on-demand access:

- **Production Runs**: When finalizing research or performing critical computations, reservations guarantee timely completion, ensuring adherence to deadlines.
- **Live Demos or Workshops**: Reservations secure exclusive device access for showcasing work or conducting workshops at specific times.
- **Streamlined Workflows**: Users can schedule reservations for tasks requiring execution at particular moments within their workflows, optimizing their overall process.

# Reservations vs. On-Demand Access

On-demand access is better suited for the initial development and prototyping stages of a quantum project. This method allows for rapid iterations without the need for pre-scheduled reservations, facilitating agile development. However, once the project progresses towards final production runs requiring guaranteed execution times, reservations become the preferred choice.
"""

```@docs
Braket.DirectReservation
Braket.start_reservation!
Braket.stop_reservation!
Braket.direct_reservation
```