package com.vectevo.deep_sky_server.shared;

import java.util.UUID;

/**
 * Domain event published inside transactional writes so FCM partner wakeups
 * execute only after database commit (`CA-07`).
 */
public record PartnerWakeupRequestedEvent(UUID coupleId, UUID senderDeviceId, String localizationKey) {}
