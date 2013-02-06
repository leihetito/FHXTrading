package com.fhx.service.ib.order;

public enum IBOrderStatus {
	PendingSubmit,
	PendingCancel,
	PreSubmitted,
	Submitted,
	Filled,
	Cancelled,
	Inactive;
}
