import 'ticket_models.dart';

abstract interface class TicketGateway {
  Future<CreatedTicketImport> createImport(
    String countryCode, {
    required String idempotencyKey,
  });

  Future<TicketPage<TicketImportProjection>> listImports({
    TicketImportState? state,
  });

  Future<TicketImportProjection> getImport(String ticketImportId);

  Future<TicketImportProjection> uploadTicket({
    required TicketUploadAuthorization authorization,
    required List<int> bytes,
    required String filename,
    required String idempotencyKey,
  });

  Future<CreatedTicketImport> refreshUploadAuthorization(
    String ticketImportId, {
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<ConfirmedTicketImport> confirmImport(
    String ticketImportId, {
    required String contextRef,
    required String? sectionLabel,
    required String? rowLabel,
    required List<String> seatLabels,
    required String idempotencyKey,
  });

  Future<TicketEvidenceResult> consumeConfirmedImport(
    ConfirmedTicketImport confirmed, {
    required String idempotencyKey,
  });

  Future<TicketPage<TicketBundleProjection>> listTickets();

  Future<TicketBundleProjection> getTicket(String ticketBundleId);
}
