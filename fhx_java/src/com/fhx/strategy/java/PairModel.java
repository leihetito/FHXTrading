package com.fhx.strategy.java;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Properties;

import org.marketcetera.trade.Order;

public class PairModel implements IModel {

	private String name;
	private Properties property;
	private List<Order> orderList;

	public PairModel(String name, Properties p) {
		this.name = name;
		this.property = p;
		this.orderList = new ArrayList<Order>();
	}

	@Override
	public String getName() {
		// TODO Auto-generated method stub
		return this.name;
	}

	@Override
	public Properties getProperties() {
		// TODO Auto-generated method stub
		return this.property;
	}

	@Override
	public String[] getPropertyNames() {
		// TODO Auto-generated method stub
		List<Object> l = new ArrayList<Object>(this.property.keySet());

		return l.toArray(new String[l.size()]);
	}

	@Override
	public String getType() {
		// TODO Auto-generated method stub
		return "PairModel";
	}

	public List<Order> getOrders() {
		// TODO Auto-generated method stub
		return new ArrayList<Order>(this.orderList); // no, return a copy here
	}

	public void addOrders(Order order) {
		// TODO Auto-generated method stub
		this.orderList.add(order);
	}

}
