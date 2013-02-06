package com.fhx.strategy.java;

import java.util.List;
import java.util.Properties;

import org.marketcetera.trade.Order;

public interface IModel {

	public String getName();

	public String getType();

	public Properties getProperties();

	public String[] getPropertyNames();

	public List<Order> getOrders();

	public void addOrders(Order order);
}
