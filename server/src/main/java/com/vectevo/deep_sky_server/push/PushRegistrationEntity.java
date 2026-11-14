package com.vectevo.deep_sky_server.push;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "push_registrations")
public class PushRegistrationEntity {

	@Id
	private UUID id;

	@Column(name = "device_id", nullable = false, unique = true, length = 64)
	private String deviceId;

	@Column(name = "couple_id", length = 64)
	private String coupleId;

	@Column(name = "fcm_token", nullable = false)
	private String fcmToken;

	@Column(name = "platform", nullable = false, length = 16)
	private String platform;

	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;

	@Column(name = "last_wakeup_at")
	private Instant lastWakeupAt;

	protected PushRegistrationEntity() {}

	public PushRegistrationEntity(
			UUID id,
			String deviceId,
			String coupleId,
			String fcmToken,
			String platform,
			Instant updatedAt) {
		this.id = id;
		this.deviceId = deviceId;
		this.coupleId = coupleId;
		this.fcmToken = fcmToken;
		this.platform = platform;
		this.updatedAt = updatedAt;
	}

	public UUID getId() {
		return id;
	}

	public String getDeviceId() {
		return deviceId;
	}

	public String getCoupleId() {
		return coupleId;
	}

	public void setCoupleId(String coupleId) {
		this.coupleId = coupleId;
	}

	public String getFcmToken() {
		return fcmToken;
	}

	public void setFcmToken(String fcmToken) {
		this.fcmToken = fcmToken;
	}

	public String getPlatform() {
		return platform;
	}

	public Instant getUpdatedAt() {
		return updatedAt;
	}

	public void setUpdatedAt(Instant updatedAt) {
		this.updatedAt = updatedAt;
	}

	public Instant getLastWakeupAt() {
		return lastWakeupAt;
	}

	public void setLastWakeupAt(Instant lastWakeupAt) {
		this.lastWakeupAt = lastWakeupAt;
	}
}
